// ============================================================================
// This file is part of Bifrost
//
// Copyright (c) 2025 Jeff Wandling
// All Rights Reserved.
//
// Licensed under BSD 3-Clause
// Redistribution and use in source and binary forms, with or without
// modification, are permitted under the terms of the BSD 3-Clause license.
// See the LICENSE file for the full text.
// ============================================================================
#include <stdint.h>
#include "lcd_config.h"
#include "lcd_NHD_0108HZ.h"

void  update_lcd_disp_string(char* pdest, uint32_t* pcounter)
{
	  // if null string
	  if (pcounter == 0) {
		  // this is an error
		  pdest[0] = 'E';
		  pdest[1] = 'R';
		  pdest[2] = 'R';
		  pdest[3] = 0;
		  return;
	  }

	  unsigned int c = *pcounter;

      if (c == 0 ) {
		  pdest[0] = '0';
		  pdest[1] = 0;
		  return;
	  }

	  char tmp[LCD_MAX_COL+1];
	  
	  if (c >= LCD_MAX_NUM) {
		  c = *pcounter = 0;
	  }

      for(int i = 0; i < LCD_MAX_COL; i++)
	  {
		  tmp[i] = 0;
		  pdest[i] = 0;
	  }

	  int idx = 0;
	  while (c)
	  {
		  uint32_t dig = c % 10;
		  tmp[idx] = '0' + dig; 
		  c = c - dig;
		  c /= 10;
		  idx++;
	  }
	  for(int i = 0 ; i < idx; i++)
	  {
		 pdest[idx - i - 1] = tmp[i];
	  }
	  pdest[idx] = 0;
}
