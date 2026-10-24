------------------------------------------------------------------------------
--                                                                          --
--                  GNAT RUN-TIME LIBRARY (GNARL) COMPONENTS                --
--                                                                          --
--            S Y S T E M . B B . B O A R D _ P A R A M E T E R S           --
--                                                                          --
--                                  S p e c                                 --
--                                                                          --
--  NUCLEO-F767ZI override of the installed light-tasking-stm32f769disco   --
--  runtime's board parameters. NOT part of the Bifrost project tree's own --
--  build -- see the README.md alongside this file for why this has to be --
--  copied into the toolchain's own gnat_user/ directory rather than       --
--  living in bifrost.gpr's Source_Dirs, and the AHB_Base_Parameters.HSE=  --
--  25MHz vs 8MHz rationale.                                               --
------------------------------------------------------------------------------

--  This package defines board parameters for the NUCLEO-F767ZI, derived
--  from the installed stm32f769disco profile's own s-bbbopa.ads (same
--  file, only HSE_Clock_Frequency changed -- see README.md).

package System.BB.Board_Parameters is
   pragma No_Elaboration_Code_All;
   pragma Pure;

   --------------------
   -- Hardware clock --
   --------------------

   Main_Clock_Frequency : constant := 200_000_000;
   --  Unchanged from the stock stm32f769disco profile. F767ZI's silicon
   --  (STM32F767ZI) is memory-map-identical to the STM32F769NI this
   --  runtime was built for (confirmed against ST's datasheets -- see
   --  ../../../../HARDWARE.md); 200MHz is comfortably within both parts'
   --  rated range with overdrive enabled (Activate_Overdrive in
   --  setup_pll.adb), so there is no reason to request a different
   --  SYSCLK just because the board changed.

   HSE_Clock_Frequency : constant := 8_000_000;
   --  THE reason this override file exists. The stock profile's own
   --  s-bbbopa.ads hardcodes 25_000_000 -- correct for the STM32F769-
   --  DISCOVERY board this runtime profile is named for and was built
   --  against (that board carries its own 25MHz crystal), but NUCLEO-
   --  F767ZI is a different board on different silicon-adjacent hardware:
   --  its HSE comes from the ST-LINK's 8MHz MCO output by default (no
   --  crystal populated on the X3 footstamp), or, if X3 is populated with
   --  the reference-design crystal, that part is itself specified at
   --  8MHz too -- so 8MHz is correct either way this board is actually
   --  wired, not just the "no crystal populated" case.
   --
   --  Setup_Pll (gnat/setup_pll.adb, unmodified by this override) derives
   --  PLLM directly from this constant: PLLM = HSE_Clock / 1_000_000 = 8,
   --  landing exactly on the "first divider M set to produce a 1MHz
   --  clock" design intent its own comment describes -- no knock-on
   --  override of PLLN/PLLP/PLLQ needed, since those are computed from
   --  PLLP_Value and Main_Clock_Frequency (unchanged) rather than from
   --  HSE_Clock_Frequency. Re-derived by hand against setup_pll.adb's
   --  actual Initialize_Clocks arithmetic, not assumed:
   --    PLLM = 8_000_000 / 1_000_000 = 8
   --    PLLN = (PLLP_Value * Main_Clock_Frequency) / 1_000_000
   --         = (2 * 200_000_000) / 1_000_000 = 400
   --    PLLVC0 = 1MHz * PLLN = 400MHz (within the part's 100-432MHz VCO
   --             range)
   --    PLLCLKOUT = PLLVC0 / PLLP_Value = 400 / 2 = 200MHz = Main_Clock_
   --                Frequency, satisfying setup_pll.adb's own
   --                "Cannot generate requested clock" compile-time check.

   FLASH_Latency : constant := 6;
   PLLP_Value    : constant := 2;
   PLLQ_Value    : constant := 7;
   --  Unchanged from the stock profile -- these depend on Main_Clock_
   --  Frequency and the part's voltage-scaling/overdrive characteristics,
   --  not on HSE_Clock_Frequency, and F767ZI shares those characteristics
   --  with the F769NI this runtime targets (see HARDWARE.md).

end System.BB.Board_Parameters;
