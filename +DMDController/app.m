function varargout = app(varargin)
%APP  Opens the DMD control panel.
%
%   DMDController.app()            a panel that owns its DMD (the ALP-5.0 device; Connect
%                                  opens it)
%   DMDController.app(dmd)         attaches to a DMDController.DMD you have (never
%                                  disconnects it)
%   DMDController.app('Driver', DMDController.SimulatedDriver())
%                                  the simulated device, no hardware
%   DMDController.app(..., 'Name', value)   options of DMDController.gui.DMDApp
%   a = DMDController.app(...)     returns the DMDController.gui.DMDApp object
%
% See also: DMDController.gui.DMDApp, DMDController.DMD
    appObject = DMDController.gui.DMDApp(varargin{:});
    if nargout > 0
        varargout{1} = appObject;
    end
end
