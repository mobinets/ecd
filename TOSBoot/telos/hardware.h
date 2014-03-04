// $Id: hardware.h,v 1.3 2005/09/19 23:40:11 jpolastre Exp $

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

#ifndef __HARDWARE_H__
#define __HARDWARE_H__

#include "msp430hardware.h"

// internal flash is 16 bits in width
typedef uint16_t in_flash_addr_t;
// external flash is 32 bits in width
typedef uint32_t ex_flash_addr_t;

void wait(uint16_t t) {
  for ( ; t > 0; t-- );
}

// LEDs
TOSH_ASSIGN_PIN(RED_LED, 5, 4);
TOSH_ASSIGN_PIN(GREEN_LED, 5, 5);
TOSH_ASSIGN_PIN(YELLOW_LED, 5, 6);

// FLASH
TOSH_ASSIGN_PIN(FLASH_OUT, 3, 1);
TOSH_ASSIGN_PIN(FLASH_IN, 3, 2);
TOSH_ASSIGN_PIN(FLASH_CLK, 3, 3);
TOSH_ASSIGN_PIN(FLASH_PWR, 4, 3);
TOSH_ASSIGN_PIN(FLASH_CS, 4, 4);

void TOSH_SET_PIN_DIRECTIONS(void)
{
  P3SEL = 0x0E; // set SPI and I2C to mod func

  //LEDS
  TOSH_MAKE_RED_LED_OUTPUT();
  TOSH_MAKE_GREEN_LED_OUTPUT();
  TOSH_MAKE_YELLOW_LED_OUTPUT();
  
  //FLASH PINS
  TOSH_MAKE_FLASH_OUT_OUTPUT();
  TOSH_MAKE_FLASH_IN_INPUT();
  TOSH_MAKE_FLASH_CLK_OUTPUT();
  TOSH_MAKE_FLASH_PWR_OUTPUT();
  TOSH_SET_FLASH_PWR_PIN();
  TOSH_MAKE_FLASH_CS_OUTPUT();
  TOSH_SET_FLASH_CS_PIN();
}

#endif
