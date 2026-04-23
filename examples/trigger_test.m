dmd = DMDController.DMD();
  dmd.connect();
  C = DMDController.Constants;
  dmd.device.projControl(C.ALP_PROJ_MODE, C.ALP_SLAVE);
  dmd.device.control(C.ALP_TRIGGER_EDGE, C.ALP_EDGE_FALLING);
  W = dmd.device.width; H = dmd.device.height;
  img = zeros(H, W, 'uint8');
  dmd.displaySequence(img, 10, 0);  % projStartCont — same as trigger_toggle

  % Now send your trigger pulse. The DMD should briefly show black (it's already black)
  % Let's just watch ALP_PROJ_STATE:
  for i = 1:50
      state = dmd.device.projInquire(C.ALP_PROJ_STATE);
      fprintf('State: %d (ACTIVE=%d)\n', state, C.ALP_PROJ_ACTIVE);
      pause(0.1);
  end
  dmd.disconnect();