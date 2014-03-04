// $Id: DelugeStorageM.nc,v 1.1 2005/07/22 17:40:08 jwhui Exp $

/*									tab:2
 *
 *
 * "Copyright (c) 2000-2005 The Regents of the University  of California.  
 * All rights reserved.
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose, without fee, and without written agreement is
 * hereby granted, provided that the above copyright notice, the following
 * two paragraphs and the author appear in all copies of this software.
 * 
 * IN NO EVENT SHALL THE UNIVERSITY OF CALIFORNIA BE LIABLE TO ANY PARTY FOR
 * DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES ARISING OUT
 * OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN IF THE UNIVERSITY OF
 * CALIFORNIA HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 * 
 * THE UNIVERSITY OF CALIFORNIA SPECIFICALLY DISCLAIMS ANY WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE.  THE SOFTWARE PROVIDED HEREUNDER IS
 * ON AN "AS IS" BASIS, AND THE UNIVERSITY OF CALIFORNIA HAS NO OBLIGATION TO
 * PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS."
 *
 */

/**
 * @author Jonathan Hui <jwhui@cs.berkeley.edu>
 */

module DelugeStorageM {
  provides {
    interface DelugeMetadataStore as MetadataStore;
    interface DelugeDataRead as DataRead;
    interface DelugeDataWrite as DataWrite;
    interface DelugeStorage;
  }
  uses {
    interface BlockRead[blockstorage_t blockId];
    interface BlockWrite[blockstorage_t blockId];
    interface Mount[blockstorage_t blockId];
    interface StorageRemap[blockstorage_t blockId];
    interface Leds;
  }
}

implementation {

  enum {
    S_NEVER_USED,
    S_MOUNTING,
    S_IDLE,
    S_METADATA_READ,
    S_METADATA_WRITE,
    S_READ,
    S_WRITE,
    S_ERASE,
    S_VERIFY,
    S_COMMIT,
  };

  uint8_t state = S_NEVER_USED;
  uint8_t client;
  uint16_t crcScratch;
  uint8_t pgNum;

  void signalDone(result_t result) {
    uint8_t tmpState = state;
    state = S_IDLE;
    switch(tmpState) {
    case S_METADATA_READ: signal MetadataStore.readDone(result); break;
    case S_READ: signal DataRead.readDone(result); break;
    case S_METADATA_WRITE: signal MetadataStore.writeDone(result); break;
    case S_WRITE: signal DataWrite.writeDone(result); break;
    case S_ERASE: signal DataWrite.eraseDone(result); break;
    case S_VERIFY: signal DataRead.verifyDone(result, crcScratch); break;
    case S_COMMIT: signal DataWrite.commitDone(result); break;
    case S_MOUNTING:
      if (result == FAIL)
	state = S_NEVER_USED;
      signal DelugeStorage.loadImagesDone(result);
      break;
    }
  }

  command result_t DelugeStorage.loadImages() {

    result_t result;

    if (state != S_NEVER_USED)
      return FAIL;
    
    client = 0;

    result = call Mount.mount[DELUGE_IMAGES[client].imageNum](DELUGE_IMAGES[client].volumeId);

    if (result == SUCCESS)
      state = S_MOUNTING;

    return result;

  }

  event void Mount.mountDone[volume_t volume](storage_result_t result, volume_id_t id) { 

    if (result != STORAGE_OK) {
      signalDone(FAIL);
      return;
    }
    
    // mount next image
    if ( ++client < DELUGE_NUM_IMAGES ) {
      if (call Mount.mount[DELUGE_IMAGES[client].imageNum](DELUGE_IMAGES[client].volumeId) == FAIL)
	signalDone(FAIL);
      return;
    }

    // mounted all images
    signalDone(SUCCESS);

  }

  command uint32_t DelugeStorage.imgNum2Addr(imgnum_t imgNum) {
    if (imgNum == DELUGE_GOLDEN_IMAGE_NUM)
      return TOSBOOT_GOLDEN_IMG_ADDR;
    return call StorageRemap.physicalAddr[DELUGE_IMAGES[imgNum].imageNum](0);
  }

  result_t newRequest(uint8_t newState, imgnum_t imgNum, 
		      block_addr_t addr, void* buf, uint16_t len) {
    
    result_t result = FAIL;
    uint8_t image = DELUGE_IMAGES[imgNum].imageNum;

    if (state != S_IDLE)
      return FAIL;
    
    switch(newState) {
    case S_VERIFY:
      pgNum = addr;
      addr = DELUGE_METADATA_SIZE + sizeof(uint16_t) * pgNum;
      buf = &crcScratch;
      len = sizeof(crcScratch);
      // no break
    case S_METADATA_READ: case S_READ:
      result = call BlockRead.read[image](addr, buf, len);
      break;
    case S_METADATA_WRITE: case S_WRITE:
      result = call BlockWrite.write[image](addr, buf, len);
      break;
    case S_ERASE:
      result = call BlockWrite.erase[image]();
      break;
    case S_COMMIT:
      result = call BlockWrite.commit[image]();
      break;
    }

    if (result == SUCCESS)
      state = newState;

    return result;

  }

  command result_t MetadataStore.read(imgnum_t imgNum, void* buf) {
    return newRequest(S_METADATA_READ, imgNum, 0, buf, sizeof(DelugeImgDesc));
  }

  command result_t MetadataStore.write(imgnum_t imgNum, void* buf) {
    return newRequest(S_METADATA_WRITE, imgNum, 0, buf, sizeof(DelugeImgDesc));
  }
  
  command result_t DataRead.read(imgnum_t imgNum, block_addr_t addr,
				 void* buf, uint16_t length) {
    return newRequest(S_READ, imgNum, addr, buf, length);
  }
  
  command result_t DataRead.verify(imgnum_t imgNum, pgnum_t tmpPgNum) {
    return newRequest(S_VERIFY, imgNum, tmpPgNum, NULL, 0);
  }

  command result_t DataWrite.write(imgnum_t imgNum, block_addr_t addr, 
				   void* buf, uint16_t length) {
    return newRequest(S_WRITE, imgNum, addr, buf, length);
  }
  
  command result_t DataWrite.erase(imgnum_t imgNum) {
    return newRequest(S_ERASE, imgNum, 0, 0, 0);
  }

  command result_t DataWrite.commit(imgnum_t imgNum) {
    return newRequest(S_COMMIT, imgNum, 0, 0, 0);
  }
  
  event void BlockRead.readDone[uint8_t volume](storage_result_t result, block_addr_t addr, void* buf, block_addr_t len) {

    uint16_t tmpLen;

    if ( pgNum == 0 ) {
      addr = DELUGE_CRC_BLOCK_SIZE;
      tmpLen = DELUGE_BYTES_PER_PAGE-DELUGE_CRC_BLOCK_SIZE;
    }
    else {
      addr = (block_addr_t)pgNum*DELUGE_BYTES_PER_PAGE;
      tmpLen = DELUGE_BYTES_PER_PAGE;
    }

    if ( result != STORAGE_OK 
	 || state == S_READ
	 || call BlockRead.computeCrc[volume]( addr + DELUGE_METADATA_SIZE, tmpLen ) == FAIL )
      signalDone(result);

  }
  
  event void BlockRead.computeCrcDone[uint8_t volume](storage_result_t result, uint16_t crc, block_addr_t addr, block_addr_t len) {
    crcScratch = ( crc == crcScratch );
    signalDone(result);
  }

  event void BlockWrite.writeDone[uint8_t volume](storage_result_t result, block_addr_t addr, void* buf, block_addr_t len) {
    signalDone(result);
  }

  event void BlockWrite.eraseDone[uint8_t volume](storage_result_t result) { 
    signalDone(result);
  } 

  event void BlockWrite.commitDone[uint8_t volume](storage_result_t result) {
    signalDone(result);
  }

  event void BlockRead.verifyDone[uint8_t volume](storage_result_t result) {}

  default command result_t BlockRead.read[blockstorage_t blockId](block_addr_t addr, void* buf, block_addr_t len) { return FAIL; }
  default command result_t BlockRead.verify[blockstorage_t blockId]() { return FAIL; }
  default command result_t BlockRead.computeCrc[blockstorage_t blockId](block_addr_t addr, block_addr_t len) { return FAIL; }
  default command result_t BlockWrite.write[blockstorage_t blockId](block_addr_t addr, void* buf, block_addr_t len) { return FAIL; }
  default command result_t BlockWrite.erase[blockstorage_t blockId]() { return FAIL; }
  default command result_t BlockWrite.commit[blockstorage_t blockId]() { return FAIL; }
  default command result_t Mount.mount[blockstorage_t blockId](volume_id_t id) { return FAIL; }
  default command uint32_t StorageRemap.physicalAddr[blockstorage_t blockId](uint32_t id) { return STORAGE_INVALID_ADDR; }

}
