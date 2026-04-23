% FETCH_GPIO_INFO  Fetch and display DMD physical pin roles and settings.
% This version is updated for the V5090 Controller Board (10-pin X1 connector).

dmd = DMDController.DMD();
try
    dmd.connect();
    C = DMDController.Constants;
    dev = dmd.device; 
    
    % --- Power and Connection Health ---
    fprintf('\n--- Board Health ---\n');
    try
        dmdMode = dev.inquire(C.ALP_DEV_DMD_MODE);
        modeStr = 'RESUME (Operational)';
        if dmdMode == C.ALP_DMD_POWER_FLOAT, modeStr = 'POWER_FLOAT (Low Power/Safe)'; end
        fprintf('DMD Power Mode: %s\n', modeStr);
    catch
        fprintf('DMD Power Mode: [Inquiry Failed]\n');
    end

    try
        dmdType = dev.inquire(C.ALP_DEV_DMDTYPE);
        typeStr = 'Unknown';
        switch dmdType
            case C.ALP_DMDTYPE_WQXGA_400MHZ_090A, typeStr = 'WQXGA (V-7002 / DLP9000X)';
            case C.ALP_DMDTYPE_DISCONNECT,         typeStr = 'DISCONNECTED (Check Power!)';
        end
        fprintf('DMD Connection: %s\n', typeStr);
    catch
        fprintf('DMD Connection: [Inquiry Failed]\n');
    end

    fprintf('\n========================================================\n');
    fprintf('   DMD PHYSICAL PIN ASSIGNMENTS (V5090 X1 Connector)    \n');
    fprintf('========================================================\n');
    
    % Pin 1: VCC_GPIO
    fprintf('Pin 1:  VCC_GPIO (I/O Voltage Supply, 2.5V to 5.0V)\n');
    
    % Group A: Pins 2, 3
    try
        gate1 = dev.inquire(C.ALP_DEV_DYN_SYNCH_OUT1_GATE);
        fprintf('Pin 2:  SYNCH_OUT1_GATE (Group A: Dynamic Sync Out 1) -> Value: %d\n', gate1);
    catch
        fprintf('Pin 2:  SYNCH_OUT1_GATE (Group A)\n');
    end

    try
        gate2 = dev.inquire(C.ALP_DEV_DYN_SYNCH_OUT2_GATE);
        fprintf('Pin 3:  SYNCH_OUT2_GATE (Group A: Dynamic Sync Out 2) -> Value: %d\n', gate2);
    catch
        fprintf('Pin 3:  SYNCH_OUT2_GATE (Group A)\n');
    end

    % Group B: Pins 4, 5
    try
        gate3 = dev.inquire(C.ALP_DEV_DYN_SYNCH_OUT3_GATE);
        fprintf('Pin 4:  SYNCH_OUT3_GATE (Group B: Dynamic Sync Out 3) -> Value: %d\n', gate3);
    catch
        fprintf('Pin 4:  SYNCH_OUT3_GATE (Group B)\n');
    end
    fprintf('Pin 5:  Reserved (Group B)\n');

    % Group C: Pins 6, 7
    fprintf('Pin 6:  Reserved (Group C)\n');
    try
        trig_edge = dev.inquire(C.ALP_TRIGGER_EDGE);
        edge_str = 'RISING'; if trig_edge ~= C.ALP_EDGE_RISING, edge_str = 'FALLING'; end
        fprintf('Pin 7:  TRIGGER_IN (Group C: External Trigger Input) -> Edge: %s\n', edge_str);
    catch
        fprintf('Pin 7:  TRIGGER_IN (Group C)\n');
    end

    % Group D: Pins 8, 9
    try
        sync_pol = dev.inquire(C.ALP_SYNCH_POLARITY);
        pol_str = 'Active HIGH'; if sync_pol ~= C.ALP_LEVEL_HIGH, pol_str = 'Active LOW'; end
        
        % Check if GPIO5 mux is relevant for Pin 8 (SYNCH_OUT)
        try
            gpio5_mux = dev.inquire(C.ALP_DEV_GPIO5_PIN_MUX);
            role = 'Unknown';
            switch gpio5_mux
                case C.ALP_GPIO_STATIC_LOW,  role = 'Static LOW';
                case C.ALP_GPIO_STATIC_HIGH, role = 'Static HIGH';
                case C.ALP_GPIO_DYN_SYNCH_OUT_ACTIVE_LOW,  role = 'Dynamic Sync Out (Active Low)';
                case C.ALP_GPIO_DYN_SYNCH_OUT_ACTIVE_HIGH, role = 'Dynamic Sync Out (Active High)';
            end
            fprintf('Pin 8:  SYNCH_OUT (Group D: Frame Sync Output) -> Polarity: %s, Mode: %s\n', pol_str, role);
        catch
            fprintf('Pin 8:  SYNCH_OUT (Group D: Frame Sync Output) -> Polarity: %s\n', pol_str);
        end
    catch
        fprintf('Pin 8:  SYNCH_OUT (Group D)\n');
    end

    try
        pwm = dev.inquire(C.ALP_PWM_LEVEL);
        fprintf('Pin 9:  PWM (Group D: Pulse-Width Modulated Output) -> Level: %d%%\n', pwm);
    catch
        fprintf('Pin 9:  PWM (Group D)\n');
    end

    % Pin 10: GND
    fprintf('Pin 10: GND (Ground)\n');
    
    fprintf('========================================================\n');
    dmd.disconnect();
catch ME
    fprintf('Error: %s\n', ME.message);
    if exist('dmd','var'), dmd.disconnect(); end
end
