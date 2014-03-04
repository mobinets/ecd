// $Id: SharedMsgBufM.nc,v 1.6 2005/07/22 17:40:08 jwhui Exp $

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
 * Simple component that allows sharing of message * buffers through a
 * parameterized interface.
 *
 * @author Jonathan Hui <jwhui@cs.berkeley.edu>
 */

module SharedMsgBufM {
  provides {
    interface SharedMsgBuf;
  }
}

implementation {

  TOS_Msg msgBuf;
  bool isLocked = FALSE;

  command TOS_MsgPtr SharedMsgBuf.getMsgBuf() {
    return &msgBuf;
  }
  
  command void SharedMsgBuf.lock() {
    isLocked = TRUE;
  }

  command void SharedMsgBuf.unlock() {
    isLocked = FALSE;
    signal SharedMsgBuf.bufFree();
  }

  command bool SharedMsgBuf.isLocked() {
    return isLocked;
  }

}
