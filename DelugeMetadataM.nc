// $Id: DelugeMetadataM.nc,v 1.29 2005/09/01 22:01:33 jwhui Exp $

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

module DelugeMetadataM {
  provides {
    interface SplitControl;
    interface DelugeMetadata as Metadata;
    interface DelugeStats;
  }
  uses {
    interface Crc;
    interface DelugeMetadataStore as MetadataStore;
    interface DelugeDataRead as DataRead;
    interface DelugeDataWrite as DataWrite;
    interface DelugeStorage;
    interface FlashWP;
    interface Leds;
    interface Timer;
  }
}

implementation {

  DelugeImgDesc imgDesc[DELUGE_NUM_IMAGES];

  uint8_t curImage;
  uint8_t state;
  uint16_t crc;

  enum {
    S_INIT,
    S_SCAN_METADATA,
    S_IDLE,
    S_CLEAR_WP,
    S_SETUP,
    S_VERIFY,
    S_SET_WP,
  };

  void verifyNextPage();

  command result_t SplitControl.init() {
    state = S_INIT;
    return SUCCESS;
  }

  command result_t SplitControl.start() {
    if ( state == S_INIT )
      call Timer.start(TIMER_ONE_SHOT, 32);
    return SUCCESS;
  }

  command result_t SplitControl.stop() {
    return SUCCESS;
  }

  void signalDone() {
    state = S_IDLE;
    signal Metadata.updateDone(SUCCESS);
  }

  result_t execute() {

    result_t result = FAIL;

    switch(state) {
    case S_INIT: 
      result = call DelugeStorage.loadImages();
      break;
    case S_SCAN_METADATA:
      result = call MetadataStore.read(curImage, &imgDesc[curImage]);
      break;
    case S_CLEAR_WP:
      result = call FlashWP.clrWP();
      break;
    case S_SETUP:
      result = call DataWrite.erase(curImage);
      break;
    case S_VERIFY:
      verifyNextPage();
      result = SUCCESS;
      break;
    case S_SET_WP:
      result = call FlashWP.setWP();
      break;
    }

    if ( result == FAIL )
      call Timer.start(TIMER_ONE_SHOT, 512);

    return result;

  }

  event result_t Timer.fired() {
    execute();
    return SUCCESS;
  }

  event void DelugeStorage.loadImagesDone(result_t result) {

    if (result == SUCCESS) {
      curImage = 0;
      state = S_SCAN_METADATA;
    }
    execute();

  }

  void scanNextImage() {
    state = S_SCAN_METADATA;
    curImage++;
    if (curImage < DELUGE_NUM_IMAGES) {
      execute();
    }
    else {
      // all done, signal that metadata is ready
      state = S_IDLE;
      signal SplitControl.startDone();
    }
  }

  void verifyNextPage() {
    if ( call DataRead.verify(curImage, imgDesc[curImage].numPgsComplete) == FAIL)
      call Timer.start(TIMER_ONE_SHOT, 512);
  }

  event void MetadataStore.readDone(storage_result_t result) {

    if ( result != STORAGE_OK ) {
      call Timer.start(TIMER_ONE_SHOT, 512);
      return;
    }

    // check if metadata is corrupt
    if ( !call Metadata.isImgDescValid(&imgDesc[curImage])
	 || imgDesc[curImage].imgNum != curImage ) {
      imgDesc[curImage].vNum = DELUGE_INVALID_VNUM;
      imgDesc[curImage].imgNum = curImage;
      imgDesc[curImage].numPgs = 0;
      imgDesc[curImage].numPgsComplete = 0;
      scanNextImage();
      return;
    }
      
    verifyNextPage();

  }

  event void DataRead.verifyDone(storage_result_t result, bool isValid) {

    if (result != STORAGE_OK) {
      call Timer.start(TIMER_ONE_SHOT, 512);
      return;
    }
    
    // SCAN state
    if (state == S_SCAN_METADATA) {

      if ( isValid ) {
	imgDesc[curImage].numPgsComplete++;
	if (imgDesc[curImage].numPgsComplete < imgDesc[curImage].numPgs) {
	  verifyNextPage();
	  return;
	}
      }
      
      scanNextImage();
      
    }

    // VERIFY state
    else {
      
      if ( !isValid ) {
	imgDesc[curImage].numPgsComplete = 0;
	state = S_SETUP;
	execute();
	return;
      }

      if ( imgDesc[curImage].numPgsComplete + 1 >= imgDesc[curImage].numPgs ) {
	if (call DataWrite.commit(curImage) == FAIL)
	  call Timer.start(TIMER_ONE_SHOT, 512);
	return;
      }
      
      imgDesc[curImage].numPgsComplete++;
      signalDone();
      
    }

  }
  
  event void DataWrite.commitDone(storage_result_t result) {

    if (result != STORAGE_OK) {
      call Timer.start(TIMER_ONE_SHOT, 512);
      return;
    }

    imgDesc[curImage].numPgsComplete = imgDesc[curImage].numPgs;
    if (curImage == DELUGE_GOLDEN_IMAGE_NUM) {
      state = S_SET_WP;
      execute();
      return;
    }

    signalDone();

  }

  command bool Metadata.isImgDescValid(DelugeImgDesc* tmpImgDesc) {
    return ( tmpImgDesc->crc == call Crc.crc16(tmpImgDesc, 8)
	     && tmpImgDesc->crc != 0
	     && tmpImgDesc->imgNum < DELUGE_NUM_IMAGES );
  }

  command imgvnum_t DelugeStats.getVNum(imgnum_t imgNum) {
    return imgDesc[imgNum].vNum;
  }

  command pgnum_t DelugeStats.getNumPgs(imgnum_t imgNum) {
    return imgDesc[imgNum].numPgs;
  }

  command pgnum_t DelugeStats.getNumPgsComplete(imgnum_t imgNum) {
    return imgDesc[imgNum].numPgsComplete;
  }
  
  command result_t Metadata.receivedPage(imgnum_t imgNum, pgnum_t pgNum) {
    
    if ( state != S_IDLE || imgNum >= DELUGE_NUM_IMAGES )
      return FAIL;
    
    state = S_VERIFY;
    curImage = imgNum;
    
    if (pgNum+1 == imgDesc[imgNum].numPgs) 
    {
      call Leds.yellowOn();	
    }
    
    execute();

    return SUCCESS;
    
  }
  
  command result_t Metadata.setupNewImage(DelugeImgDesc* newImgDesc) {
    
    if (state != S_IDLE)
      return FAIL;
    
    curImage = newImgDesc->imgNum;
    state = (curImage == DELUGE_GOLDEN_IMAGE_NUM) ? S_CLEAR_WP : S_SETUP;
    
    memcpy(&(imgDesc[curImage]), newImgDesc, sizeof(DelugeImgDesc));
    imgDesc[curImage].numPgsComplete = 0;
    
    execute();
    
    return SUCCESS;
    
  }

  command DelugeImgDesc* Metadata.getImgDesc(uint8_t imgNum) {
    return &imgDesc[imgNum];
  }

  event void FlashWP.clrWPDone() {
    state = S_SETUP;
    execute();
  }

  event void FlashWP.setWPDone() {
    signalDone();
  }

  event void DataWrite.eraseDone(storage_result_t result) {

    if ( result != STORAGE_OK
	 || call MetadataStore.write(curImage, &imgDesc[curImage]) == FAIL )
      call Timer.start(TIMER_ONE_SHOT, 512);

  }
  
  event void MetadataStore.writeDone(storage_result_t result) {
    signalDone();
  }

  event void DataRead.readDone(storage_result_t result) {}
  event void DataWrite.writeDone(storage_result_t result) {}
  default event void Metadata.updateDone(result_t result) {}

}
