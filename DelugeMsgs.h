// $Id: DelugeMsgs.h,v 1.16 2005/07/22 20:11:42 jwhui Exp $

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

#ifndef __DELUGE_MSGS_H__
#define __DELUGE_MSGS_H__

#include "Deluge.h"
#include "DelugeMetadata.h"

enum {
  DELUGE_SHARED_MSG_BUF = unique("SharedMsgBuf"),
};

enum {
  AM_DELUGEADVMSG  = 161,
  AM_DELUGEREQMSG  = 162,
  AM_DELUGEDATAMSG = 163,
};

enum {
  DELUGE_ADV_NORMAL = 0,
  DELUGE_ADV_ERROR  = 1,
  DELUGE_ADV_PC     = 2,
  DELUGE_ADV_PING   = 3,
  DELUGE_ADV_RESET  = 4,
};

typedef struct DelugeAdvMsg {
  uint16_t       sourceAddr; // 2
  uint8_t        version;    // 1
  uint8_t        type;       // 1
  DelugeNodeDesc nodeDesc;   // 10
  DelugeImgDesc  imgDesc;    // 12
  uint8_t        numImages;  // 1
  uint8_t        reserved;   // 1
} DelugeAdvMsg;

typedef struct DelugeReqMsg {
  uint16_t  dest;
  uint16_t  sourceAddr;
  imgvnum_t vNum;
  imgnum_t  imgNum;
  pgnum_t   pgNum;
  uint8_t   requestedPkts[DELUGE_PKT_BITVEC_SIZE];
} DelugeReqMsg;

typedef struct DelugeDataMsg {
  imgvnum_t vNum;
  imgnum_t  imgNum;
  pgnum_t   pgNum;
  uint8_t   pktNum;
  uint16_t  sourceAddr;
  uint8_t   pendPktNum; // indicate the dissemination progress
  uint8_t   totalPktNum;
  uint8_t   metric;
  uint8_t   data[DELUGE_PKT_PAYLOAD_SIZE];
} DelugeDataMsg;

#endif
