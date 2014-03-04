// $Id: NetProgC.nc,v 1.12 2005/08/03 17:13:24 jwhui Exp $

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

includes NetProg;
includes NetProgMsgs;
includes TOSBoot;

configuration NetProgC {
  provides {
    interface NetProg;
    interface StdControl;
  }
}

implementation {

  components
    CrcC,
    DelugeMetadataC as Metadata,
    DelugeStorageC as Storage,
    Main,
    NetProgM,
    SharedMsgBufM;

#ifdef DELUGE_GENERIC_COMM_PROMISCUOUS
  components GenericCommPromiscuous as Comm;
#else
  components GenericComm as Comm;
#endif

#ifndef PLATFORM_PC
  components InternalFlashC as IFlash;
  NetProgM.IFlash -> IFlash;
#endif

  StdControl = NetProgM;
  NetProg = NetProgM;

  Main.StdControl -> Comm;

  NetProgM.Crc -> CrcC;
  NetProgM.MetadataControl -> Metadata;
  NetProgM.ReceiveMsg -> Comm.ReceiveMsg[AM_NETPROGMSG];
  NetProgM.SendMsg -> Comm.SendMsg[AM_NETPROGMSG];
  NetProgM.SharedMsgBuf -> SharedMsgBufM;
  NetProgM.Storage -> Storage;

}
