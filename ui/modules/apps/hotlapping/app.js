// Hotlapping UI Script (Angular version)
// Author: NikolasSnorkell

angular.module('beamng.apps')
.directive('hotlappingBeammp', [function () {
    return {
        templateUrl: '/ui/modules/apps/hotlapping/app.html',
        replace: true,
        restrict: 'EA',
        link: function (scope, element, attrs) {
            console.log('[Hotlapping UI] Directive initializing...');
            
            // Initialize scope variables
            scope.status = 'not_configured';
            scope.statusText = 'Не установлено';
            scope.statusClass = 'status-not-configured';
            scope.currentTime = '00:00.000';
            scope.bestTime = '--:--.---';
            scope.laps = [];
            scope.canSetPointB = false;
            scope.canClear = false;
            
            console.log('[Hotlapping UI] Initial state:', scope.statusText);
            
            // Register event listener for status updates from Lua
            scope.$on('HotlappingStatusUpdate', function (event, data) {
                console.log('[Hotlapping UI] Status update:', data);
                
                scope.status = data.status;
                scope.statusText = data.statusText;
                
                // Update status class
                switch (data.status) {
                    case 'not_configured':
                        scope.statusClass = 'status-not-configured';
                        scope.canSetPointB = false;
                        scope.canClear = false;
                        break;
                    case 'point_a_set':
                        scope.statusClass = 'status-partial';
                        scope.canSetPointB = true;
                        scope.canClear = true;
                        break;
                    case 'configured':
                        scope.statusClass = 'status-configured';
                        scope.canSetPointB = true;
                        scope.canClear = true;
                        break;
                    case 'setting_point_a':
                    case 'setting_point_b':
                        scope.statusClass = 'status-in-progress';
                        break;
                }
                
                scope.$apply();
            });
            
            // Button handlers - call Lua functions
            scope.setPointA = function () {
                console.log('[Hotlapping UI] Set Point A clicked');
                bngApi.engineLua('extensions.hotlapping_beammp.setPointA()');
            };
            
            scope.setPointB = function () {
                console.log('[Hotlapping UI] Set Point B clicked');
                
                if (scope.status === 'not_configured') {
                    console.warn('[Hotlapping UI] Cannot set Point B: Point A not set');
                    return;
                }
                
                bngApi.engineLua('extensions.hotlapping_beammp.setPointB()');
            };
            
            scope.clearPoints = function () {
                console.log('[Hotlapping UI] Clear Points clicked');
                bngApi.engineLua('extensions.hotlapping_beammp.clearPoints()');
            };
            
            scope.closeApp = function () {
                console.log('[Hotlapping UI] Close app');
                bngApi.engineLua('extensions.hotlapping_beammp.toggleUI()');
            };
            
            // Format time as MM:SS.mmm
            scope.formatTime = function (seconds) {
                if (!seconds || seconds < 0) return '00:00.000';
                
                const minutes = Math.floor(seconds / 60);
                const secs = Math.floor(seconds % 60);
                const millis = Math.floor((seconds % 1) * 1000);
                
                return String(minutes).padStart(2, '0') + ':' + 
                       String(secs).padStart(2, '0') + '.' + 
                       String(millis).padStart(3, '0');
            };
            
            console.log('[Hotlapping UI] App initialized');
        }
    };
}]);
