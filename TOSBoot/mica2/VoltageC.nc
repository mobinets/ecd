// $Id: VoltageC.nc,v 1.1 2005/07/22 17:40:10 jwhui Exp $

/*									tab:2
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

module VoltageC {
  provides {
    interface Voltage;
  }
}

implementation {

  command bool Voltage.okToProgram() {

    // set BAT_MON to HI
    TOSH_MAKE_BAT_MON_OUTPUT();
    TOSH_SET_BAT_MON_PIN();
    // 250 KHz ADC clock (4MHz/16)
    outp( 0x04, ADCSR );
    // clear interrupt flag by writing a 1
    sbi( ADCSR, ADIF );
    // setup input channel
    outp( VOLTAGE_PORT, ADMUX );
    // adc enable
    sbi( ADCSR, ADEN );
    // adc start conversion
    sbi( ADCSR, ADSC );
    // wait for conversion to complete
    while ( !bit_is_set( ADCSR, ADIF ) );

    return ( __inw(ADCL) < VTHRESH  );

  }

}
