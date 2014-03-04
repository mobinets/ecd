// $Id: DelugeStorageC.nc,v 1.1 2005/07/22 17:40:08 jwhui Exp $

/*									tab:4
 *
 *
 * "Copyright (c) 2000-2004 The Regents of the University  of California.  
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

configuration DelugeStorageC {
  provides {
    interface DelugeDataRead as DataRead;
    interface DelugeDataWrite as DataWrite;
    interface DelugeMetadataStore as MetadataStore;
    interface DelugeStorage;
  }
}
implementation {

  components
    DelugeStorageM as Storage,
    BlockStorageC,
    LedsC as Leds;

  DataRead = Storage;
  DataWrite = Storage;
  DelugeStorage = Storage;
  MetadataStore = Storage;

  Storage.Leds -> Leds;

  Storage.BlockRead[DELUGE_VOLUME_ID_0] -> BlockStorageC.BlockRead[DELUGE_VOLUME_ID_0];
  Storage.BlockWrite[DELUGE_VOLUME_ID_0] -> BlockStorageC.BlockWrite[DELUGE_VOLUME_ID_0];
  Storage.Mount[DELUGE_VOLUME_ID_0] -> BlockStorageC.Mount[DELUGE_VOLUME_ID_0];
  Storage.StorageRemap[DELUGE_VOLUME_ID_0] -> BlockStorageC.StorageRemap[DELUGE_VOLUME_ID_0];
#if DELUGE_NUM_IMAGES >= 2
  Storage.BlockRead[DELUGE_VOLUME_ID_1] -> BlockStorageC.BlockRead[DELUGE_VOLUME_ID_1];
  Storage.BlockWrite[DELUGE_VOLUME_ID_1] -> BlockStorageC.BlockWrite[DELUGE_VOLUME_ID_1];
  Storage.Mount[DELUGE_VOLUME_ID_1] -> BlockStorageC.Mount[DELUGE_VOLUME_ID_1];
  Storage.StorageRemap[DELUGE_VOLUME_ID_1] -> BlockStorageC.StorageRemap[DELUGE_VOLUME_ID_1];
#if DELUGE_NUM_IMAGES >= 3
  Storage.BlockRead[DELUGE_VOLUME_ID_2] -> BlockStorageC.BlockRead[DELUGE_VOLUME_ID_2];
  Storage.BlockWrite[DELUGE_VOLUME_ID_2] -> BlockStorageC.BlockWrite[DELUGE_VOLUME_ID_2];
  Storage.Mount[DELUGE_VOLUME_ID_2] -> BlockStorageC.Mount[DELUGE_VOLUME_ID_2];
  Storage.StorageRemap[DELUGE_VOLUME_ID_2] -> BlockStorageC.StorageRemap[DELUGE_VOLUME_ID_2];
#if DELUGE_NUM_IMAGES >= 4
  Storage.BlockRead[DELUGE_VOLUME_ID_3] -> BlockStorageC.BlockRead[DELUGE_VOLUME_ID_3];
  Storage.BlockWrite[DELUGE_VOLUME_ID_3] -> BlockStorageC.BlockWrite[DELUGE_VOLUME_ID_3];
  Storage.Mount[DELUGE_VOLUME_ID_3] -> BlockStorageC.Mount[DELUGE_VOLUME_ID_3];
  Storage.StorageRemap[DELUGE_VOLUME_ID_3] -> BlockStorageC.StorageRemap[DELUGE_VOLUME_ID_3];
#if DELUGE_NUM_IMAGES >= 5
  Storage.BlockRead[DELUGE_VOLUME_ID_4] -> BlockStorageC.BlockRead[DELUGE_VOLUME_ID_4];
  Storage.BlockWrite[DELUGE_VOLUME_ID_4] -> BlockStorageC.BlockWrite[DELUGE_VOLUME_ID_4];
  Storage.Mount[DELUGE_VOLUME_ID_4] -> BlockStorageC.Mount[DELUGE_VOLUME_ID_4];
  Storage.StorageRemap[DELUGE_VOLUME_ID_4] -> BlockStorageC.StorageRemap[DELUGE_VOLUME_ID_4];
#if DELUGE_NUM_IMAGES >= 6
  Storage.BlockRead[DELUGE_VOLUME_ID_5] -> BlockStorageC.BlockRead[DELUGE_VOLUME_ID_5];
  Storage.BlockWrite[DELUGE_VOLUME_ID_5] -> BlockStorageC.BlockWrite[DELUGE_VOLUME_ID_5];
  Storage.Mount[DELUGE_VOLUME_ID_5] -> BlockStorageC.Mount[DELUGE_VOLUME_ID_5];
  Storage.StorageRemap[DELUGE_VOLUME_ID_5] -> BlockStorageC.StorageRemap[DELUGE_VOLUME_ID_5];
#if DELUGE_NUM_IMAGES >= 7
  Storage.BlockRead[DELUGE_VOLUME_ID_6] -> BlockStorageC.BlockRead[DELUGE_VOLUME_ID_6];
  Storage.BlockWrite[DELUGE_VOLUME_ID_6] -> BlockStorageC.BlockWrite[DELUGE_VOLUME_ID_6];
  Storage.Mount[DELUGE_VOLUME_ID_6] -> BlockStorageC.Mount[DELUGE_VOLUME_ID_6];
  Storage.StorageRemap[DELUGE_VOLUME_ID_6] -> BlockStorageC.StorageRemap[DELUGE_VOLUME_ID_6];
#if DELUGE_NUM_IMAGES >= 8
  Storage.BlockRead[DELUGE_VOLUME_ID_7] -> BlockStorageC.BlockRead[DELUGE_VOLUME_ID_7];
  Storage.BlockWrite[DELUGE_VOLUME_ID_7] -> BlockStorageC.BlockWrite[DELUGE_VOLUME_ID_7];
  Storage.Mount[DELUGE_VOLUME_ID_7] -> BlockStorageC.Mount[DELUGE_VOLUME_ID_7];
  Storage.StorageRemap[DELUGE_VOLUME_ID_7] -> BlockStorageC.StorageRemap[DELUGE_VOLUME_ID_7];
#endif
#endif
#endif
#endif
#endif
#endif
#endif

}
