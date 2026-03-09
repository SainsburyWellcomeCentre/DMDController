classdef Constants
    %CONSTANTS  All ALP-5.0 #define constants (alp.h version 28).
    %
    % Access as: DMDController.Constants.ALP_OK
    % Or instantiate: c = DMDController.Constants();

    properties (Constant)

        % ----------------------------------------------------------------
        % Standard parameters
        % ----------------------------------------------------------------
        ALP_DEFAULT          = int32(0);
        ALP_ENABLE           = int32(1);
        ALP_INVALID_ID       = uint32(4294967295);  % (ALP_ID)(-1) = 0xFFFFFFFF

        % ----------------------------------------------------------------
        % Return codes
        % ----------------------------------------------------------------
        ALP_OK               = int32(0);
        ALP_NOT_ONLINE       = int32(1001);
        ALP_NOT_IDLE         = int32(1002);
        ALP_NOT_AVAILABLE    = int32(1003);
        ALP_NOT_READY        = int32(1004);
        ALP_PARM_INVALID     = int32(1005);
        ALP_ADDR_INVALID     = int32(1006);
        ALP_MEMORY_FULL      = int32(1007);
        ALP_SEQ_IN_USE       = int32(1008);
        ALP_HALTED           = int32(1009);
        ALP_ERROR_INIT       = int32(1010);
        ALP_ERROR_COMM       = int32(1011);
        ALP_DEVICE_REMOVED   = int32(1012);
        ALP_NOT_CONFIGURED   = int32(1013);
        ALP_LOADER_VERSION   = int32(1014);
        ALP_ERROR_POWER_DOWN = int32(1018);
        ALP_DRIVER_VERSION   = int32(1019);
        ALP_SDRAM_INIT       = int32(1020);
        ALP_CONFIG_MISMATCH  = int32(1021);
        ALP_ERROR_UNKNOWN    = int32(1999);

        % ----------------------------------------------------------------
        % Device state codes (AlpDevInquire ALP_DEV_STATE)
        % ----------------------------------------------------------------
        ALP_DEV_BUSY         = int32(1100);
        ALP_DEV_READY        = int32(1101);
        ALP_DEV_IDLE         = int32(1102);

        % ----------------------------------------------------------------
        % Projection state codes (AlpProjInquire ALP_PROJ_STATE)
        % ----------------------------------------------------------------
        ALP_PROJ_ACTIVE      = int32(1200);
        ALP_PROJ_IDLE        = int32(1201);

        % ----------------------------------------------------------------
        % AlpDevControl / AlpDevInquire  (ControlTypes from 2000)
        % ----------------------------------------------------------------
        ALP_DEVICE_NUMBER    = int32(2000);
        ALP_VERSION          = int32(2001);
        ALP_DEV_STATE        = int32(2002);
        ALP_AVAIL_MEMORY     = int32(2003);

        % Temperature inquire types (1 LSB = 1/256 deg C, signed)
        ALP_DDC_FPGA_TEMPERATURE      = int32(2050);
        ALP_APPS_FPGA_TEMPERATURE     = int32(2051);
        ALP_PCB_TEMPERATURE           = int32(2052);
        ALP_MAX_DDC_FPGA_TEMPERATURE  = int32(2145);
        ALP_MAX_APPS_FPGA_TEMPERATURE = int32(2146);
        ALP_MAX_PCB_TEMPERATURE       = int32(2147);

        % GPIO / sync polarity
        ALP_SYNCH_POLARITY   = int32(2004);
        ALP_TRIGGER_EDGE     = int32(2005);
        ALP_LEVEL_HIGH       = int32(2006);
        ALP_LEVEL_LOW        = int32(2007);
        ALP_EDGE_FALLING     = int32(2008);
        ALP_EDGE_RISING      = int32(2009);

        ALP_PWM_LEVEL        = int32(2063);
        ALP_DEV_DYN_SYNCH_OUT_WATCHDOG = int32(2088);

        % Dynamic sync output gate configuration (use with AlpDevControlEx)
        ALP_DEV_DYN_SYNCH_OUT1_GATE = int32(2023);
        ALP_DEV_DYN_SYNCH_OUT2_GATE = int32(2024);
        ALP_DEV_DYN_SYNCH_OUT3_GATE = int32(2025);

        % USB
        ALP_USB_CONNECTION           = int32(2016);
        ALP_USB_DISCONNECT_BEHAVIOUR = int32(2078);
        ALP_USB_IGNORE               = int32(1);
        ALP_USB_RESET                = int32(2);

        % DMD type select
        ALP_DEV_DMDTYPE              = int32(2021);
        ALP_DMDTYPE_XGA              = int32(1);
        ALP_DMDTYPE_SXGA_PLUS        = int32(2);
        ALP_DMDTYPE_1080P_095A       = int32(3);
        ALP_DMDTYPE_XGA_07A          = int32(4);
        ALP_DMDTYPE_XGA_055A         = int32(5);
        ALP_DMDTYPE_XGA_055X         = int32(6);
        ALP_DMDTYPE_WUXGA_096A       = int32(7);
        ALP_DMDTYPE_WQXGA_400MHZ_090A = int32(8);   % V-7002 default (2560x1600 @ 400 MHz)
        ALP_DMDTYPE_WQXGA_480MHZ_090A = int32(9);   % V-7002 extended (480 MHz, requires temp control)
        ALP_DMDTYPE_1080P_065A       = int32(10);
        ALP_DMDTYPE_1080P_065_S600   = int32(11);
        ALP_DMDTYPE_WXGA_S450        = int32(12);
        ALP_DMDTYPE_DLPC910REV       = int32(254);
        ALP_DMDTYPE_DISCONNECT       = int32(255);

        % Display geometry
        ALP_DEV_DISPLAY_HEIGHT = int32(2057);
        ALP_DEV_DISPLAY_WIDTH  = int32(2058);

        % DMD power mode
        ALP_DEV_DMD_MODE       = int32(2064);
        ALP_DMD_RESUME         = int32(0);
        ALP_DMD_POWER_FLOAT    = int32(1);

        % GPIO5 pin mux
        ALP_DEV_GPIO5_PIN_MUX           = int32(2062);
        ALP_GPIO_STATIC_LOW             = int32(0);
        ALP_GPIO_STATIC_HIGH            = int32(1);
        ALP_GPIO_DYN_SYNCH_OUT_ACTIVE_LOW  = int32(16);
        ALP_GPIO_DYN_SYNCH_OUT_ACTIVE_HIGH = int32(17);

        % Sequence config (before AlpSeqAlloc)
        ALP_SEQ_CONFIG               = int32(2153);
        ALP_SEQ_CONFIG_DEFAULT       = int32(0);
        ALP_SEQ_CONFIG_BITPLANE_LUT_ROW = int32(1);

        % ----------------------------------------------------------------
        % AlpSeqControl  (ControlTypes from 2100)
        % ----------------------------------------------------------------
        ALP_SEQ_REPEAT       = int32(2100);
        ALP_FIRSTFRAME       = int32(2101);
        ALP_LASTFRAME        = int32(2102);

        ALP_BITNUM           = int32(2103);
        ALP_BIN_MODE         = int32(2104);
        ALP_BIN_NORMAL       = int32(2105);
        ALP_BIN_UNINTERRUPTED = int32(2106);

        ALP_PWM_MODE         = int32(2107);
        ALP_FLEX_PWM         = int32(3);

        % Bit Plane LUT (ALP_BITPLANE_LUT_MODE = ALP_PWM_MODE)
        ALP_BITPLANE_LUT_DEFAULT = int32(0);
        ALP_BITPLANE_LUT_FRAME   = int32(6);
        ALP_BITPLANE_LUT_ROW     = int32(7);
        ALP_BITPLANE_LUT_ENTRIES = int32(2108);

        % Data format
        ALP_DATA_FORMAT          = int32(2110);
        ALP_DATA_MSB_ALIGN       = int32(0);
        ALP_DATA_LSB_ALIGN       = int32(1);
        ALP_DATA_BINARY_TOPDOWN  = int32(2);
        ALP_DATA_BINARY_BOTTOMUP = int32(3);

        ALP_SEQ_PUT_LOCK         = int32(2119);

        % Scrolling
        ALP_LINE_INC             = int32(2113);
        ALP_FIRSTLINE            = int32(2111);
        ALP_LASTLINE             = int32(2112);
        ALP_SCROLL_FROM_ROW      = int32(2123);
        ALP_SCROLL_TO_ROW        = int32(2124);

        % X offset (sequence)
        ALP_X_OFFSET             = int32(2359);
        ALP_X_OFFSET_SELECT      = int32(2154);
        ALP_X_OFFSET_GLOBAL      = int32(0);
        ALP_X_OFFSET_SEQ         = int32(1);

        % Frame LUT (FLUT) mode
        ALP_FLUT_MODE            = int32(2118);
        ALP_FLUT_NONE            = int32(0);
        ALP_FLUT_9BIT            = int32(1);
        ALP_FLUT_18BIT           = int32(2);
        ALP_FLUT_ENTRIES9        = int32(2120);
        ALP_FLUT_OFFSET9         = int32(2122);

        % Area of Interest (AOI)
        ALP_SEQ_DMD_LINES        = int32(2125);

        % X shear
        ALP_X_SHEAR_SELECT       = int32(2132);

        % DMD mask
        ALP_DMD_MASK_SELECT      = int32(2134);
        ALP_DMD_MASK_16X16       = int32(1);
        ALP_DMD_MASK_16X8        = int32(2);

        % Dynamic sync out (sequence)
        ALP_SEQ_DYN_SYNCH_OUT_PERIOD     = int32(2150);
        ALP_SEQ_DYN_SYNCH_OUT_PULSEWIDTH = int32(2151);

        % ----------------------------------------------------------------
        % AlpSeqInquire  (additional InquireTypes from 2200)
        % ----------------------------------------------------------------
        ALP_BITPLANES            = int32(2200);
        ALP_PICNUM               = int32(2201);
        ALP_PICTURE_TIME         = int32(2203);
        ALP_ILLUMINATE_TIME      = int32(2204);
        ALP_SYNCH_DELAY          = int32(2205);
        ALP_SYNCH_PULSEWIDTH     = int32(2206);
        ALP_TRIGGER_IN_DELAY     = int32(2207);
        ALP_MAX_SYNCH_DELAY      = int32(2209);
        ALP_MAX_TRIGGER_IN_DELAY = int32(2210);
        ALP_MIN_PICTURE_TIME     = int32(2211);
        ALP_MIN_ILLUMINATE_TIME  = int32(2212);
        ALP_MAX_PICTURE_TIME     = int32(2213);
        ALP_ON_TIME              = int32(2214);
        ALP_OFF_TIME             = int32(2215);

        % ----------------------------------------------------------------
        % AlpProjControl / AlpProjInquire  (from 2300 / 2400)
        % ----------------------------------------------------------------
        ALP_PROJ_MODE            = int32(2300);
        ALP_MASTER               = int32(2301);
        ALP_SLAVE                = int32(2302);
        ALP_PROJ_STEP            = int32(2329);

        ALP_PROJ_INVERSION       = int32(2306);
        ALP_PROJ_UPSIDE_DOWN     = int32(2307);
        ALP_PROJ_LEFT_RIGHT_FLIP = int32(2346);

        ALP_Y_OFFSET             = int32(2360);

        % FLUT write (use with AlpProjControlEx)
        ALP_FLUT_MAX_ENTRIES9    = int32(2324);
        ALP_FLUT_WRITE_9BIT      = int32(2325);
        ALP_FLUT_WRITE_18BIT     = int32(2326);

        % X shear write (use with AlpProjControlEx)
        ALP_X_SHEAR              = int32(2337);

        % DMD mask write (use with AlpProjControlEx)
        ALP_DMD_MASK_WRITE_16K   = int32(2351);
        ALP_DMD_MASK_WRITE       = int32(2339);

        % BPLUT (use with AlpProjControlEx)
        ALP_BPLUT_MAX_ENTRIES    = int32(2356);
        ALP_BPLUT_WRITE          = int32(2357);

        % Sequence Queue API
        ALP_PROJ_QUEUE_MODE      = int32(2314);
        ALP_PROJ_LEGACY          = int32(0);
        ALP_PROJ_SEQUENCE_QUEUE  = int32(1);
        ALP_PROJ_QUEUE_ID        = int32(2315);
        ALP_PROJ_QUEUE_MAX_AVAIL = int32(2316);
        ALP_PROJ_QUEUE_AVAIL     = int32(2317);
        ALP_PROJ_PROGRESS        = int32(2318);
        ALP_PROJ_RESET_QUEUE     = int32(2319);
        ALP_PROJ_ABORT_SEQUENCE  = int32(2320);
        ALP_PROJ_ABORT_FRAME     = int32(2321);
        ALP_PROJ_ABORT_ASYNC     = int32(2345);
        ALP_PROJ_WAIT_UNTIL      = int32(2323);
        ALP_PROJ_WAIT_PIC_TIME   = int32(0);
        ALP_PROJ_WAIT_ILLU_TIME  = int32(1);

        ALP_PROJ_STATE           = int32(2400);

        % Progress flags
        ALP_FLAG_QUEUE_IDLE            = uint32(1);
        ALP_FLAG_SEQUENCE_ABORTING     = uint32(2);
        ALP_FLAG_SEQUENCE_INDEFINITE   = uint32(4);
        ALP_FLAG_FRAME_FINISHED        = uint32(8);

        % ----------------------------------------------------------------
        % LED types (AlpLedAlloc LedType)
        % ----------------------------------------------------------------
        ALP_HLD_PT120_RED        = int32(257);   % 0x0101
        ALP_HLD_PT120_RAX        = int32(268);   % 0x010c
        ALP_HLD_PT120_GREEN      = int32(258);   % 0x0102
        ALP_HLD_PT120_BLUE       = int32(259);   % 0x0103
        ALP_HLD_PT120TE_BLUE     = int32(263);   % 0x0107
        ALP_HLD_CBT90_UV         = int32(265);   % 0x0109
        ALP_HLD_CBT120_UV        = int32(260);   % 0x0104
        ALP_HLD_CBM120_UV365     = int32(266);   % 0x010a
        ALP_HLD_CBM120_UV        = int32(267);   % 0x010b
        ALP_HLD_CBM90X33_IRD     = int32(270);   % 0x010e
        ALP_HLD_CBM120_FR        = int32(272);   % 0x0110
        ALP_HLD_CBT90_WHITE      = int32(262);   % 0x0106
        ALP_HLD_CBT140_WHITE     = int32(264);   % 0x0108
        ALP_HLD_C_MULTI_405GR    = int32(269);   % 0x010d
        ALP_HLD_C_MULTI_RGB      = int32(271);   % 0x010f

        % LED control/inquire types
        ALP_LED_SET_CURRENT        = int32(1001);
        ALP_LED_BRIGHTNESS         = int32(1002);
        ALP_LED_FORCE_OFF          = int32(1003);
        ALP_LED_AUTO_OFF           = int32(0);
        ALP_LED_OFF                = int32(1);
        ALP_LED_ON                 = int32(2);
        ALP_LED_TYPE               = int32(1101);
        ALP_LED_MEASURED_CURRENT   = int32(1102);
        ALP_LED_TEMPERATURE_REF    = int32(1103);
        ALP_LED_TEMPERATURE_JUNCTION = int32(1104);
        ALP_LED_ALLOC_PARAMS       = int32(2101);

        % ----------------------------------------------------------------
        % Put line transfer mode
        % ----------------------------------------------------------------
        ALP_PUT_LINES              = uint32(1);

    end

    methods (Static)
        function str = returnCodeString(code)
            %RETURNCODESTRING  Human-readable string for an ALP return code.
            c = DMDController.Constants;
            names = {'ALP_OK','ALP_NOT_ONLINE','ALP_NOT_IDLE','ALP_NOT_AVAILABLE', ...
                     'ALP_NOT_READY','ALP_PARM_INVALID','ALP_ADDR_INVALID', ...
                     'ALP_MEMORY_FULL','ALP_SEQ_IN_USE','ALP_HALTED', ...
                     'ALP_ERROR_INIT','ALP_ERROR_COMM','ALP_DEVICE_REMOVED', ...
                     'ALP_NOT_CONFIGURED','ALP_LOADER_VERSION', ...
                     'ALP_ERROR_POWER_DOWN','ALP_DRIVER_VERSION', ...
                     'ALP_SDRAM_INIT','ALP_CONFIG_MISMATCH','ALP_ERROR_UNKNOWN'};
            for i = 1:numel(names)
                if int32(code) == int32(c.(names{i}))
                    str = names{i};
                    return;
                end
            end
            str = sprintf('UNKNOWN(%d)', code);
        end
    end

end
