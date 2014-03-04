// $Id: SharedMsgBuf.nc,v 1.5 2005/07/22 17:40:08 jwhui Exp $

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
 * Simple component that allows sharing of message buffers through a
 * parameterized interface.
 *
 * @author Jonathan Hui <jwhui@cs.berkeley.edu>
 */

interface SharedMsgBuf {

  /**
   * Get the pointer to a shared message buf.
   *
   * @return The pointer to the shared message buf.
   */
  command TOS_MsgPtr getMsgBuf();

  /**
   * Acquire lock on shared message buf.
   */
  command void lock();

  /**
   * Release lock on shared message buf.
   */
  command void unlock();

  /**
   * Check if shared message buf is currently locked.
   *
   * @return <code>TRUE</code> if the shared message buf is locked;
   *         <code>FALSE</code> otherwise.
   */
  command bool isLocked();

  /**
   * Signal that the bus is free to allow other components waiting to
   * begin using it right away.
   */
  event void bufFree();

}
