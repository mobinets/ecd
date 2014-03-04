// $Id: DelugeC.nc,v 1.24 2005/08/03 17:13:15 jwhui Exp $

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

includes BitVecUtils;
includes crc;
includes Deluge;
includes DelugeMetadata;
includes DelugeMsgs;
includes NetProg;

configuration DelugeC {
  provides {
    interface StdControl;
  }
}

implementation {

  components
    Main,
    BitVecUtilsC,
    CrcC,
    DelugeM,
    DelugeMetadataC as Metadata,
    DelugePageTransferC as PageTransfer,
    NetProgC,
    RandomLFSR,
    SharedMsgBufM,
    TimerC;

#ifdef DELUGE_GENERIC_COMM_PROMISCUOUS
  components GenericCommPromiscuous as Comm;
#else
  components GenericComm as Comm;
#endif

#ifdef DELUGE_LEDS
  components LedsC as Leds;
#else
  components NoLeds as Leds;
#endif

#ifndef PLATFORM_PC
  components InternalFlashC as IFlash;
  DelugeM.IFlash -> IFlash;
#endif

  StdControl = DelugeM;

  Main.StdControl -> NetProgC;

  DelugeM.MetadataControl -> Metadata;
  DelugeM.PageTransferControl -> PageTransfer;

  DelugeM.Crc -> CrcC;
  DelugeM.Leds -> Leds;
  DelugeM.Metadata -> Metadata;
  DelugeM.NetProg -> NetProgC;
  DelugeM.PageTransfer -> PageTransfer;
  DelugeM.Random -> RandomLFSR;
  DelugeM.ReceiveAdvMsg -> Comm.ReceiveMsg[AM_DELUGEADVMSG];
  DelugeM.SendAdvMsg-> Comm.SendMsg[AM_DELUGEADVMSG];
  DelugeM.SharedMsgBuf -> SharedMsgBufM;
  DelugeM.Timer -> TimerC.Timer[unique("Timer")];

  PageTransfer.Leds -> Leds;
  PageTransfer.ReceiveDataMsg -> Comm.ReceiveMsg[AM_DELUGEDATAMSG];
  PageTransfer.ReceiveReqMsg -> Comm.ReceiveMsg[AM_DELUGEREQMSG];
  PageTransfer.SendDataMsg -> Comm.SendMsg[AM_DELUGEDATAMSG];
  PageTransfer.SendReqMsg -> Comm.SendMsg[AM_DELUGEREQMSG];
  PageTransfer.SharedMsgBuf -> SharedMsgBufM;

#ifndef PLATFORM_PC
  components BcastC;
  DelugeM.Bcast -> BcastC;
#endif
}
