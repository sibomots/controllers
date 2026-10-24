------------------------------------------------------------------------------
--                                                                          --
--                         GNAT RUN-TIME COMPONENTS                         --
--                                                                          --
--  NUCLEO-F767ZI override of the installed light-tasking-stm32f769disco   --
--  runtime's PLL bring-up. NOT part of the Bifrost project tree's own     --
--  build -- see ../README.md alongside this file for why this has to be  --
--  copied into the toolchain's own gnat_user/ directory rather than      --
--  living in bifrost.gpr's Source_Dirs.                                  --
--                                                                          --
--  Identical to the installed stm32f769disco profile's own setup_pll.adb --
--  except for one constant: HSE_Bypass, False -> True. See below.        --
------------------------------------------------------------------------------

pragma Ada_2012;
pragma Suppress (All_Checks);

--  This initialization procedure mainly initializes the PLLs and
--  all derived clocks.

with Ada.Unchecked_Conversion;

with Interfaces.STM32;           use Interfaces, Interfaces.STM32;
with Interfaces.STM32.FLASH;     use Interfaces.STM32.FLASH;
with Interfaces.STM32.RCC;       use Interfaces.STM32.RCC;

with System.BB.Parameters;       use System.BB.Parameters;
with System.BB.MCU_Parameters;
with System.BB.Board_Parameters; use System.BB.Board_Parameters;
with System.STM32;               use System.STM32;
with System.Machine_Reset;

procedure Setup_Pll is
   procedure Initialize_Clocks;
   procedure Reset_Clocks;

   ------------------------------
   -- Clock Tree Configuration --
   ------------------------------

   HSE_Enabled     : constant Boolean := True;  -- use high-speed ext. clock

   --  THE ONLY CHANGE FROM THE STOCK FILE. NUCLEO-F767ZI's HSE (at least
   --  until an actual crystal is populated at X3) is driven by the
   --  ST-LINK's own 8MHz MCO output -- an ACTIVE digital clock signal,
   --  not a passive crystal/resonator. The stock value here (False) tells
   --  the chip to drive its own crystal-oscillator amplifier circuit,
   --  which expects a passive resonator completing a feedback loop, not
   --  an actively-driven signal. Confirmed, not guessed: with this at
   --  False, HSERDY and PLLRDY both report success, but the achieved
   --  clock empirically measures at almost exactly 1/3 of the intended
   --  frequency (measured two independent ways -- UART baud needing
   --  38400 instead of a computed 115200, and Ada.Real_Time ticking at
   --  1/3 rate over a real, stopwatch-timed 30-second interval) --
   --  consistent with the oscillator amplifier locking onto a parasitic
   --  subharmonic of the actively-driven signal rather than tracking it,
   --  a real, known failure mode for this exact misconfiguration.
   --  Setting this True puts OSC_IN into plain external-clock-input mode
   --  instead, which is what an actively-driven HSE source needs.
   --
   --  If a real passive crystal/resonator is ever populated at X3
   --  instead of relying on the ST-LINK MCO, THIS MUST BE SET BACK TO
   --  FALSE -- bypass mode is specifically for active external clock
   --  sources, not passive crystals.
   HSE_Bypass      : constant Boolean := True;

   LSI_Enabled     : constant Boolean := True;  -- use low-speed internal clock

   Activate_PLL       : constant Boolean := True;
   Activate_Overdrive : constant Boolean := True;
   Activate_PLLI2S    : constant Boolean := False;

   pragma Compile_Time_Error (not (if Activate_PLL then HSE_Enabled),
                              "PLL only supported with external clock");

   pragma Compile_Time_Error (Activate_PLLI2S, "not yet implemented");

   -----------------------
   -- Initialize_Clocks --
   -----------------------

   procedure Initialize_Clocks
   is
      -------------------------------
      -- Compute Clock Frequencies --
      -------------------------------

      PLLCLKIN    : constant Integer := 1_000_000;
      PLLM_Value  : constant Integer  := HSE_Clock / PLLCLKIN;
      --  First divider M is set to produce a 1Mhz clock

      PLLN_Value  : constant Integer :=
                      (PLLP_Value * Clock_Frequency) / PLLCLKIN;
      --  Compute N to to generate the required frequency

      PLLVC0      : constant Integer := PLLCLKIN * PLLN_Value;
      PLLCLKOUT   : constant Integer := PLLVC0 / PLLP_Value;

      pragma Compile_Time_Error
        (PLLP_Value not in PLLP_Range,
         "Invalid PLLP clock configuration value");
      pragma Compile_Time_Error
        (PLLQ_Value not in PLLQ_Range,
         "Invalid PLLQ clock configuration value");

      PLLM        : constant UInt6 := UInt6 (PLLM_Value);
      PLLN        : constant UInt9 := UInt9 (PLLN_Value);
      --  PLLP and PLLQ are configured in System.BB.Board_Parameters
      PLLP        : constant UInt2 := UInt2 (PLLP_Value / 2 - 1);
      PLLQ        : constant UInt4 := UInt4 (PLLQ_Value);

      SW          : constant SYSCLK_Source :=
                      (if Activate_PLL then SYSCLK_SRC_PLL
                       else (if HSE_Enabled then SYSCLK_SRC_HSE
                             else SYSCLK_SRC_HSI));
      SW_Value    : constant CFGR_SW_Field :=
                      SYSCLK_Source'Enum_Rep (SW);

      SYSCLK      : constant Integer := (if Activate_PLL
                                         then PLLCLKOUT
                                         else HSICLK);

      HCLK        : constant Integer :=
                      (if not AHB_PRE.Enabled
                       then SYSCLK
                       else
                         (case AHB_PRE.Value is
                             when DIV2   => SYSCLK / 2,
                             when DIV4   => SYSCLK / 4,
                             when DIV8   => SYSCLK / 8,
                             when DIV16  => SYSCLK / 16,
                             when DIV64  => SYSCLK / 64,
                             when DIV128 => SYSCLK / 128,
                             when DIV256 => SYSCLK / 256,
                             when DIV512 => SYSCLK / 512));
      PCLK1       : constant Integer :=
                      (if not APB1_PRE.Enabled
                       then HCLK
                       else
                         (case APB1_PRE.Value is
                             when DIV2  => HCLK / 2,
                             when DIV4  => HCLK / 4,
                             when DIV8  => HCLK / 8,
                             when DIV16 => HCLK / 16));
      PCLK2       : constant Integer :=
                      (if not APB2_PRE.Enabled
                       then HCLK
                       else
                         (case APB2_PRE.Value is
                             when DIV2  => HCLK / 2,
                             when DIV4  => HCLK / 4,
                             when DIV8  => HCLK / 8,
                             when DIV16 => HCLK / 16));

      function To_AHB is new Ada.Unchecked_Conversion
        (AHB_Prescaler, UInt4);
      function To_APB is new Ada.Unchecked_Conversion
        (APB_Prescaler, UInt3);

   begin

      --  Check configuration
      pragma Compile_Time_Error
        (PLLVC0 not in PLLVC0_Range or else PLLCLKOUT not in PLLOUT_Range,
           "Invalid clock configuration");

      pragma Compile_Time_Error
        (SYSCLK /= Clock_Frequency,
           "Cannot generate requested clock");

      --  Cannot be checked at compile time, depends on APB1_PRE and APB2_PRE
      if HCLK not in HCLK_Range
         or else PCLK1 not in PCLK1_Range
         or else PCLK2 not in PCLK2_Range
      then
         --  Invalid AHB/APB prescalers configuration.
         --  We cannot raise an exception here as the runtime is not fully
         --  initialized yet.
         System.Machine_Reset.Stop;
      end if;

      --  PWR clock enable

      RCC_Periph.APB1ENR.PWREN := 1;

      --  Reset the power interface
      RCC_Periph.APB1RSTR.PWRRST := 1;
      RCC_Periph.APB1RSTR.PWRRST := 0;

      --  PWR initialization
      --  Select higher supply power for stable operation at max. freq.
      --  See table "General operating conditions" of the STM32 datasheets
      --  to obtain the maximal operating frequency depending on the power
      --  scaling mode and the over-drive mode

      System.BB.MCU_Parameters.PWR_Initialize;

      if not HSE_Enabled then
         --  Setup internal clock and wait for HSI stabilisation.

         RCC_Periph.CR.HSION := 1;

         loop
            exit when RCC_Periph.CR.HSIRDY = 1;
         end loop;

      else
         --  Configure high-speed external clock, if enabled

         RCC_Periph.CR.HSEON := 1;
         RCC_Periph.CR.HSEBYP := (if HSE_Bypass then 1 else 0);

         loop
            exit when RCC_Periph.CR.HSERDY = 1;
         end loop;
      end if;

      --  Configure low-speed internal clock if enabled

      if LSI_Enabled then
         RCC_Periph.CSR.LSION := 1;

         loop
            exit when RCC_Periph.CSR.LSIRDY = 1;
         end loop;
      end if;

      --  Activate PLL if enabled
      if Activate_PLL then
         --  Disable the main PLL before configuring it
         RCC_Periph.CR.PLLON := 0;

         --  Configure the PLL clock source, multiplication and division
         --  factors
         RCC_Periph.PLLCFGR :=
           (PLLM   => PLLM,
            PLLN   => PLLN,
            PLLP   => PLLP,
            PLLQ   => PLLQ,
            PLLSRC => (if HSE_Enabled
                       then PLL_Source'Enum_Rep (PLL_SRC_HSE)
                       else PLL_Source'Enum_Rep (PLL_SRC_HSI)),
            others => <>);

         RCC_Periph.CR.PLLON := 1;
         loop
            exit when RCC_Periph.CR.PLLRDY = 1;
         end loop;
      end if;

      --  Configure OverDrive mode
      if Activate_Overdrive then
         System.BB.MCU_Parameters.PWR_Overdrive_Enable;
      end if;

      --  Configure flash
      --  Must be done before increasing the frequency, otherwise the CPU
      --  won't be able to fetch new instructions.

      FLASH_Periph.ACR.ICEN := 0;
      FLASH_Periph.ACR.DCEN := 0;
      FLASH_Periph.ACR.ICRST := 1;
      FLASH_Periph.ACR.DCRST := 1;
      FLASH_Periph.ACR :=
        (LATENCY => FLASH_Latency,
         ICEN    => 1,
         DCEN    => 1,
         PRFTEN  => 1,
         others  => <>);

      --  Configure derived clocks

      RCC_Periph.CFGR :=
        (SW      => SW_Value,
         HPRE    => To_AHB (AHB_PRE),
         PPRE    => (As_Array => True,
                     Arr      => (1 => To_APB (APB1_PRE),
                                  2 => To_APB (APB2_PRE))),
         RTCPRE  => 16#0#,
         I2SSRC  => I2S_Clock_Selection'Enum_Rep (I2SSEL_PLL),
         MCO1    => MCO1_Clock_Selection'Enum_Rep (MCO1SEL_HSI),
         MCO1PRE => MCOx_Prescaler'Enum_Rep (MCOxPRE_DIV1),
         MCO2    => MCO2_Clock_Selection'Enum_Rep (MCO2SEL_SYSCLK),
         MCO2PRE => MCOx_Prescaler'Enum_Rep (MCOxPRE_DIV5),
         others  => <>);

      if Activate_PLL then
         loop
            exit when RCC_Periph.CFGR.SWS =
              SYSCLK_Source'Enum_Rep (SYSCLK_SRC_PLL);
         end loop;

         --  Wait until voltage supply scaling has completed

         loop
            exit when System.BB.MCU_Parameters.Is_PWR_Stabilized;
         end loop;
      end if;
   end Initialize_Clocks;

   ------------------
   -- Reset_Clocks --
   ------------------

   procedure Reset_Clocks is
   begin
      --  Switch on high speed internal clock
      RCC_Periph.CR.HSION := 1;

      --  Reset CFGR regiser
      RCC_Periph.CFGR := (others => <>);

      --  Reset HSEON, CSSON and PLLON bits
      RCC_Periph.CR.HSEON := 0;
      RCC_Periph.CR.CSSON := 0;
      RCC_Periph.CR.PLLON := 0;

      --  Reset PLL configuration register
      RCC_Periph.PLLCFGR := (others => <>);

      --  Reset HSE bypass bit
      RCC_Periph.CR.HSEBYP := 0;

      --  Disable all interrupts
      RCC_Periph.CIR := (others => <>);
   end Reset_Clocks;

begin
   Reset_Clocks;
   Initialize_Clocks;
end Setup_Pll;
