/*Author: Roman Sanzharov (Moscow, Russia) 12.09.2022
MC: ATtiny13A. CPU clock = 4.8 MHz (internal RC-oscillator)
PB0, PB1 - outputs (PWM)
PA2...PA5 - inputs pullup (buttons)
RESET disabled*/
//--------------------------------------------------------------------------------------------------------------
#define F_CPU 4800000UL    // CPU clock frequency value for delay.h
#include <avr/io.h>        //
#include <util/delay.h>    //
#include <avr/eeprom.h>    //

#define     power_button 3 // PB3 - "on/off" button
#define     color_button 4 // PB4 - "change PWM pin" button
#define increment_button 2 // PB2 - "increase PWM duty" button
#define decrement_button 5 // PB5 - "decrease PWM duty" button

typedef enum{false, true} bool; //

uint8_t brightness EEMEM = 0; // PWM duty level [0...9] register in the EEPROM
uint8_t      color EEMEM = 0; // PWM pin number [0, 1] register in the EEPROM

uint8_t      power_value = 0; // Device condition flag (0 - off, 1 - on)
uint8_t brightness_value;     // Current PWM duty value [0...9]
uint8_t      color_value;     // Current PWM pin nimber [0, 1]

volatile uint8_t brs_arr[10] = {25, 50, 75, 100, 125, 150, 175, 200, 225, 255}; // PWM duty value array
//-----------------------------------------------------------------------------------------------------------
void set_color(){                    // Subprogramm of changing current PWM pin number
	switch (color_value){            // 
		case 0: // white             // 
			TCCR0A &= 0b00001111;    //
			TCCR0A |= (1 << COM0A1); // If color_value = 0, PWM --> PB0
			break;                   //
		case 1: // yellow            //
			TCCR0A &= 0b00001111;    //
			TCCR0A |= (1 << COM0B1); // If color_value = 1, PWM --> PB1
			break;                   //
	}                                //
}                                    //
//*********************************************
void set_brightness(){                       // Subprogramm of changing current PWM duty
	uint8_t tmp = brs_arr[brightness_value]; // 
	OCR0A = tmp;                             // 
	OCR0B = tmp;                             //
}                                            //
//*********************************************
void power_function(){            // "on/off" button processing routine
	power_value ^= (1 << 0);      // Invert device condition flag (0 --> 1 or 1 --> 0)
	switch (power_value){         // Device condition flag = 0 ?
		case 0:                   //
			TCCR0A &= 0b00001111; // No - disconnect PB0 and PB1 from PWM
			break;                // 
		case 1:                   //
			set_color();          // Yes - set_color subprogramm
			break;                //
	}                             //
}                                 //
//*********************************************
void color_function(){                       // "change PWM pin" button processing routine
	color_value ^= (1 << 0);                 // Invert current PWM pin nimber (0 --> 1 or 1 --> 0)
	set_color();                             // Set_color subprogramm
	eeprom_write_byte (&color, color_value); // Write current PWM pin nimber in the EEPROM
	eeprom_busy_wait();                      // Wait until EEPROM is ready
}                                            // 
//*******************************************************
void increment_function(){                             // "increase PWM duty" button processing routine
	brightness_value++;                                // Increment current PWM duty value
	if (brightness_value == 10){                       // Is current PWM duty value in range [0...9] ?
		brightness_value = 9;                          // No - constrain to 9
	}                                                  //
	set_brightness();                                  // Set_brightness subprogramm
	eeprom_write_byte (&brightness, brightness_value); // Write current PWM duty value in the EEPROM
	eeprom_busy_wait();                                // Wait until EEPROM is ready
}                                                      //
//*******************************************************
void decrement_function(){                             // "decrease PWM duty" button processing routine
	brightness_value--;                                // Decrement current PWM duty value
	if (brightness_value == 255){                      // Is current PWM duty value in range [0...9] ?
		brightness_value = 0;                          // No - constrain to 0
	}                                                  //
	set_brightness();                                  // Set_brightness subprogramm
	eeprom_write_byte (&brightness, brightness_value); // Write current PWM duty value in the EEPROM
	eeprom_busy_wait();                                // Wait until EEPROM is ready
}                                                      //
//************************************************************
void button_read(){                                         // Subprogramm of reading buttons pressings
	if ((PINB & (1 << power_button)) == 0){                 // Is "on/off" button pressed ?
		_delay_ms(30);                                      // Yes - delay 30 ms
		power_function();                                   // Power_function subprogramm
		while ((PINB & (1 << power_button)) == 0){}         // Is button released ? No - wait
		_delay_ms(30);                                      // Yes - delay 30 ms
	}                                                       //
	if (power_value){                                       // Is device condition flag set ? Yes - 
		if ((PINB & (1 << color_button)) == 0){             // Is "change PWM pin" button pressed ?
			_delay_ms(30);                                  // Yes - delay 30 ms
			color_function();                               // Color_function subprogramm
			while ((PINB & (1 << color_button)) == 0){}     // Is button released ? No - wait
			_delay_ms(30);                                  // Yes - delay 30 ms
		}                                                   //
		if ((PINB & (1 << increment_button)) == 0){         // Is "increase PWM duty" button pressed ?
			_delay_ms(30);                                  // Yes - delay 30 ms
			increment_function();                           // Increment_function subprogramm
			while ((PINB & (1 << increment_button)) == 0){} // Is button released ? No - wait
			_delay_ms(30);                                  // Yes - delay 30 ms
		}                                                   // 
		if ((PINB & (1 << decrement_button)) == 0){         // Is "decrease PWM duty" button pressed ?
			_delay_ms(30);                                  // Yes - delay 30 ms
			decrement_function();                           // Decrement_function subprogramm
			while ((PINB & (1 << decrement_button)) == 0){} // Is button released ? No - wait
			_delay_ms(30);                                  // Yes - delay 30 ms
		}                                                   //
	}                                                       //
}                                                           //
//***************************************************************************
void INIT(){                                                               // MC initialisation subprogramm
	brightness_value = eeprom_read_byte (&brightness);                     // Read current PWM duty value from EEPROM
	     color_value = eeprom_read_byte (&color);                          // Read current PWM pin nimber from EEPROM
	set_brightness();                                                      // Set_brightness subprogramm
	DDRB = (1 << DDB0) | (1 << DDB1);                                      // PB0, PB1 - outputs (PWM)
	PORTB = (1 << PORTB2) | (1 << PORTB3) | (1 << PORTB4) | (1 << PORTB5); // PB2...PB5 - inputs pullup (buttons)
	TCCR0A = (1 << WGM00) | (1 << WGM01);                                  // Timer/counter 0 --> Fast PWM mode (see datascheet)
	TCCR0B =  (1 << CS00) | (1 << CS01);                                   // TCNT0 prescaller = 64 (see datascheet)
}                                                                          // 4.8 MHz / 64 = 75 kHz
                                                                           // 75 kHz / 256 = 293 Hz (PWM frequency)
//-----------------------------------------------------------------------------------------------------------
int main(){
	INIT();
	while(1){
		button_read();
	}
	return 0;
}
