function testsimpwalk2step(defaultparms)% TESTSIMPWALK2STEP    simplest walking model periodic step%% Perform a test of the simplest walking model equations in 2D.% Starting with the symbolic equations of motion, % test alternative equations using pose Jacobian and constraint Jacobian.% State vector:% x = [q1; q2; q1dot; q2dot], angles of stance and% swing legs, and respective angular velocities.% All angles are measured counter-clockwise from vertical.% Default model parameters % Base units:% M = total body mass, L = leg length, g = gravitational acceleration%   (These are set to unity, so that the model is effectively dimensioned%    by M, L, g as base units. All other units are relative to these.)% Simplest model parameters:%   gamma = downward slope (rad), M = pelvis mass, m = foot mass%   (where foot mass is taken as very small),%   Kp = pelvis torsional spring acting between legsx0 = [0.3 -0.3 -0.3 -0.25]'; % state vector: x = [q1; q2; q1dot; q2dot]    if nargin < 1 % set default parameters     defaultparms = struct('M', 1, 'L', 1, 'g', 1, ...        'gamma', 0.016, 'Kp', 0, 'm', 1e-11, ...        'sim', struct('tmax', 5, 'ntimesteps', 18));end % otherwise parms may be specified as argumentparms = defaultparms;% Set parameters valuesM = parms.M; L = parms.L; g = parms.g;gamma = parms.gamma; Kp = parms.Kp; %% Find a periodic gait% Define an error function, the root of which will denote a fixed point% (state corresponding to periodic gait or limit cycle)fixedpointerror = @(x) onestepsimpwalk2(x, parms) - x;% Next search for the actual fixed point% Search for the initial conditionxstar = findroot(fixedpointerror, x0);disp('Here is the error in fixed point:');disp(fixedpointerror(xstar)') %% One step simulationparms = defaultparms; % reset parms structure to original[xe,te,ts,xs] = onestepsimpwalk2(x0, parms);disp('Initial condition for next step:')disp(xe')disp('Ending time of step:')disp(te)plot(ts, xs) % times and states over a full stepxlabel('Time (dimensionless)');ylabel('States'); legend('q1','q2','q1dot','q2dot');%% Test for energy conservation% Compute the total energy and verify that it is conserved over time% check for energy conservation during the simulation[energies, KEs, PEs] = energysimpwalk2(xs, parms); % for all states over timeclfsubplot(121);plot(ts, xs(:,1:2)); xlabel('Time'); ylabel('Angles'); legend('q1', 'q2');subplot(122);plot(ts, energies, ts, KEs, ts, PEs); xlabel('Time'); ylabel('Energy');legend('Total', 'KE','PE');title('Energy conservation')disp('Paused. Press a key to continue.');pause;%% Animate the step% Compute an entire step at equal time steps and store the results:parms.sim.ntimesteps = 18; % set # of time steps as simulation parameter% Use the periodic gait to run one step simulation[xnext, tcontact, ts, xs] = onestepsimpwalk2(0, xstar, parms);  clf; animatesimpwalk2(xs,2, parms) % Animate the step for two steps%% End of testsimpwalk2step; local functions follow%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%function [xnext,tcontact,ts,xs] = onestepsimpwalk2(t0, x0, optparms)% [xnext,tcontact,ts,xs] = onestepsimpwalk2([t0, ] x0 [, parms])% onestepsimpwalk2 performs one step of the simplest dynamic walking% model.  Inputs are initial state x0.% returns xnext (initial state of next step), tcontact, % and arrays ts and xs containing steps from integration.% If you intend to animate the simulation, include the% simulation paramter parms.sim.ntimesteps to the number of% equally spaced frames desired.%% Optionally can be called with an initial time,%   onestepsimpwalk2(t0, x0)% Optionally can be called with parameters structure%   onestepsimpowalk2([t0,], x0, parms)% where parms should either be in enclosing scope, or final argument.% Simulation parameters in enclosing scope:%   parms.sim.tmax parms.sim.ntimestepsif nargin == 1 % if only one argument is given, assume it is x0  x0 = t0; t0 = 0;elseif nargin == 2 % need to figure out whether second argument is parms  if isstruct(x0)    parms = x0; % input was x0, parms    x0 = t0; t0 = 0;   else          % input was t0, x0 so parms should be in scope    if ~exist('parms',1) % doesn't exist      error('No parms struct in scope');    end  endelseif nargin == 3   % explicitly fed parms struct  parms = optparms;end% these statements are necessary in order to set event handling:% ode45 will stop the integration when the event occursoptions = odeset('events', @eventsimpwalk2);% Here is how to use an "anonymous function" which turns a function% like f(t, x, parms) into something that can be called with f2(t, x):%   f2 = @(t,x) f(t, x, parms)% where parms is needed by function f, but is embedded into the f2% function.%% Here we use the anonymous function to the state-derivative function:fstatederiv = @(t,x) fsimpwalk2(t, x, parms);% integrate using ode45 and the state-derivative functionodesol = ode45(@(t,x) fsimpwalk2(t,x,parms), [t0 t0+parms.sim.tmax], x0, options);ts = odesol.x'; % time vector (as a column)xs = odesol.y'; % states array (states as rows, time as column);tcontact = odesol.xe;xe = odesol.ye;if isempty(xe)    warning('no event detected by ode45');endxminus = xe;  % event-detected state% Computes initial state for next step:xnext = s2ssimpwalk2(xminus, parms);if nargout == 0  % if no output, plot just the angles  plot(ts, xs(:,1:2))end% check for equal time steps, e.g. for animationif parms.sim.ntimesteps ~= 0 % any non-zero value means equal time steps    ts = linspace(ts(1), ts(end), parms.sim.ntimesteps);    xs = deval(odesol, ts)'; % use the solution structure to evaluate                            % states at arbitrary time points (deval)endend % onestepsimpwalk2%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%function xdot = fsimpwalk2(t,x,optparms)% state derivative function for a simple walker with point masses% The following variables are available in this% subfunction:  gamma M L g Kpif nargin == 3 % parameters fed in as third argument    parms = optparms;end            % otherwise expect parms to be in scope% Parameters: M L g gamma M = parms.M; L = parms.L; g = parms.g;Kp = parms.Kp; % hip springgamma = parms.gamma;% Define constants% Define forces: % State assignmentsq1 = x(1); q2 = x(2); u1 = x(3); u2 = x(4); c1m2 = cos(q1 - q2); s1m2 = sin(q1 - q2); MM = zeros(2,2); rhs = zeros(2,1);% Mass MatrixMM(1,1) = M; MM(1,2) = 0; MM(2,1) = -c1m2; MM(2,2) = 1; % righthand side termsrhs(1) = g/L*M*sin(q1 - gamma); rhs(2) = -Kp*(q2-q1) -s1m2*(u1*u1) - g/L*sin(q2 - gamma); udot = MM\rhs;xdot = [x(3); x(4); udot];end % fsimpwalk2%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%function xdot = fsimpwalk2m(t,x,optparms)% state-derivative function for simplest dynamic walking model% state is [q1; q2; q1dot; q2dot]% calculates state derivative for two-segment, 2-D dynamic% walking model with point mass pelvis, light point feet.%% This version includes full equations with pelvis mass M and % foot mass m, without taking the limit m/M -> 0. Use this% version to test other methods of deriving equations.sif nargin == 3 % parameters fed in as third argument    parms = optparms;end            % otherwise expect parms to be in scope% Parameters: M L g gamma M = parms.M; L = parms.L; g = parms.g;Kp = parms.Kp; % hip springgamma = parms.gamma; m = parms.m; % foot mass% Define constants% Define forces: % State assignmentsq1 = x(1); q2 = x(2); u1 = x(3); u2 = x(4); c1m2 = cos(q1 - q2); s1m2 = sin(q1 - q2); % The full equations of motion% [ (M+m)*L^2        -m*L^2*cos(q1-q2) ] [u1dot] % [ -m*L^2*cos(q1-q2)     m*L^2        ] [u2dot] %% = [ -(M+m)*g*L*sin(gamma-q1) + m*L^2*sin(q1-q2)*u2^2 - K*(q1-q2) ]%   [ m*g*L*sin(gamma-q2) - m*L^2*sin(q1-q2)*u1^2 - K*(q2-q1)      ]%% Replace K = Kp*m*L^2 (i.e. Kp is a torsional stiffness with respect% to swing leg)%% Also divide both equations by M*L^2:% [ 1                -(m/M)*cos(q1-q2) ] [u1dot] % [ -(m/M)*cos(q1-q2)       (m/M)      ] [u2dot] %% = [ -(1+m/M)*(g/L)*sin(gamma-q1) + (m/M)*sin(q1-q2)*u2^2 - Kp*m/M*(q1-q2) ]%   [ (m/M)*(g/L)*sin(gamma-q2)    - (m/M)*sin(q1-q2)*u1^2 - Kp*m/M*(q2-q1) ]%% First row: Take limit m/M -> 0% Second row: Divide by (m/M)% [ 1                         0  ] [u1dot] % [ -cos(q1-q2)         1        ] [u2dot] %% = [ -(g/L)*sin(gamma-q1)                                       ]%   [  (g/L)*sin(gamma-q2) - sin(q1-q2)*u1^2 - Kp*(q2-q1) ]%% Notice that Kp acts on the swing leg, but the reaction torque on% the stance leg is infinitesimal.MM = zeros(2,2); rhs = zeros(2,1);% Mass MatrixMM(1,1) = 1; MM(1,2) = -(m/M)*c1m2; MM(2,1) = -(m/M)*c1m2; MM(2,2) = (m/M); % righthand side termsrhs(1) = -(1+m/M)*(g/L)*sin(gamma - q1) + (m/M)*s1m2*(u2*u2) - Kp*(m/M)*(q1-q2); rhs(2) = (m/M)*(g/L)*sin(gamma - q2) -(m/M)*s1m2*(u1*u1) - Kp*(m/M)*(q2-q1); % note that the second row of the equations can be divided by (m/M)% as is the case for the analytical version fsimpwalk2. Here the% (m/M) is not divided out, to facilitate comparison with the Jacobian% methods.udot = MM\rhs;xdot = [x(3); x(4); udot];end % fsimpwalk2%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%function [value, isterminal, direction] = eventsimpwalk2(t, x, optparms)% returns event function for passive walking simulation% Here is how event checking works:  % At each integration step, ode45 checks to see if an% event function passes through zero (in this case, we need% the function to go through zero when the foot hits the% ground).  It finds the value of the event function by calling% eventswalk2, which is responsible for returning the value of the % event function in variable value.  isterminal should contain% a 1 to signify that the integration should stop (otherwise it% will keep going after value goes through zero).  Finally,% direction should specify whether to look for event function% going through zero with positive or negative slope, or either.if nargin == 3 % parameters fed in as third argument    parms = optparms;end            % otherwise expect parms to be in scope% we want to stop the simulation when theta = alpha% or when (theta - alpha) is zeroq1 = x(1); q2 = x(2); u1 = x(3); u2 = x(4);value = cos(q1) - cos(q2);% Here is a trick to use to ignore heel scuffing, by % making sure the stance leg is past vertical before% an event causes the simulation to stop% This effectively only allows "long-period" gaits.if q1 < 0 % A criterion other than 0 angle can also improve          % robustness, but can limit range of acceptable slopes  isterminal = 1;  % tells ode45 to stop when event occurselse  isterminal = 0;  % keep goingenddirection = -1;  % tells ode45 to look for negative crossingend % event simplest walker%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%function [E, KE, PE] = energysimpwalk2(x, optparms)% ENERGYSIMPWALK2  returns total energy of the simpelst walking model% [E, KE, PEN] = energysimpwalk2(x [,parms]) takes in the state vector and% returns the total energy, kinetic energy, and potential% energy of the walker for that state vector.%% If x is a 2D array with state vectors arranged in rows, then% energy is computed for each row/state vector, and returned% as a column of sequential energy values.if nargin == 2 % parameters fed in as third argument    parms = optparms;end            % otherwise expect parms to be in scopeM = parms.M; g = parms.g; L = parms.L; Kp = parms.Kp;if length(x) == 4  % Only 4 states  q1 = x(1); q2 = x(2); u1 = x(3); u2 = x(4);else               % Or an array of state vectors, each a row  q1 = x(:,1); q2 = x(:,2); u1 = x(:,3); u2 = x(:,4);endPE = M*g*L*cos(q1 - gamma); % gravitational potential energy% note that Kp is a weak spring relative to swing leg% PEs = 0.5*Kp*(q2-q1).^2;     % spring potential energy (weak compared to%                              % pelvis, since swing leg is light.KE  = 0.5*M*(u1*L).^2;       % kinetic energyE = PE + KE;end % energy simplest walker%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%function xnew = s2ssimpwalk2(xminus, optparms)% calculates the new state following foot contact.% Angular momentum is conserved about the impact point for the% whole machine, and about the hip joint for the trailing leg.% After conservation of angular momentum is applied, the legs% are switched.% State vector: qstance, qswing, qdotstance, qdotswingif nargin == 3 % parameters fed in as third argument    parms = optparms;end            % otherwise expect parms to be in scope% Parameters: M L g gamma KpM = parms.M; L = parms.L; g = parms.g;gamma = parms.gamma; Kp = parms.Kp;sg = sin(gamma); cg = cos(gamma);MM = zeros(2,2);amb = zeros(2,1);q1 = xminus(1); q2 = xminus(2); u1 = xminus(3); u2 = xminus(4);c1 = cos(q1); c2 = cos(q2); c12 = cos(q1-q2);s1 = sin(q1); s2 = sin(q2); s12 = sin(q1-q2);% Angular momentum before impact:%   amb(1) is angular momentum of whole system about heel contact%   amb(2) is angular momentum of trailing leg about the hipamb(1) = cos(q1-q2)*u1;amb(2) = cos(q1-q2)^2*u1;% Angular momentum after heel strike:%   The first row of MM gives angular momentum of whole system about heel%   contact, with MM(1,:)*thetadotplus%   The second row of MM gives angular momentum of trailing leg about hip%   with MM(2,:)*thetadotplusMM(1,1) = 0;MM(1,2) = 1;MM(2,1) = 1;MM(2,2) = 0;unew = MM\amb;  % solve for thetadotplus with a linear systemxnew = [xminus(2); xminus(1); unew(2); unew(1)];% note leg positions are switched hereend % heelstrike simplest walker%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%function [xdot,lambdas] = fsimpwalk2Jc(t,x, optparms)% Calculates the state-derivative, using the constraint Jacobian% method.% State vector: qstance, qswing, qdotstance, qdotswing% This version uses the augmented Newton-Euler method, and% allows for an optional second output: lambdasif nargin == 3 % parameters fed in as third argument    parms = optparms;end            % otherwise expect parms to be in scope% Parameters: M L g gamma M = parms.M; L = parms.L; g = parms.g;gamma = parms.gamma; % Pelvis is mass M. Point mass with no moment of inertiaMp = M; Ip = 0;% Here Ml is the mass of the leg (without pelvis), dominated by% foot mass m.Ml = parms.m; Il = 0;  % leg is otherwise massless, no moment of inertiasg = sin(gamma);cg = cos(gamma);q1 = x(1); q2 = x(2); % q1 is angle of stance leg ccw wrt verticalu1 = x(3); u2 = x(4); % q2 is angle of swing leg ccw wrt verticalc1 = cos(q1); c2 = cos(q2); c12 = cos(q1-q2);s1 = sin(q1); s2 = sin(q2); s12 = sin(q1-q2);% The constraint Jacobian will be used to perform the augmented% Newton-Euler method, in terms of the "maximal" coordinates X.% But since our simulation already uses the minimal state vector x,% we first need to convert from x to X:% Calculate pose Jacobian, giving center of mass motions of each segment% so that Jp*u yields something like this: %   [x1dot; y1dot; th1dot; xpdot; ypdot; thpdot; x2dot; y2dot;%   th2dot]% referring to velocities in x, y, and theta for segments 1, 2 and% the pelvis p (which we're treating as a separate segment)Jp  = [-0*c1      0      ;  % velocity of stance leg COM x       -0*s1      0      ;  % velocity of stance leg COM y         1        0      ;  % angular velocity of stance leg       -(L*c1)    0      ;  % velocity of pelvis x       -(L)*s1    0      ;  % velocity of pelvis y         1        0      ;  % angular velocity of pelvis       -(L*c1) (L)*c2    ;  % velocity of swing leg COM x       -(L*s1) (L)*s2    ;  % velocity of swing leg COM y         0        1      ]; % angular velocity of swing leg          % Let V = Xdot be the vector containing the full velocities of all segments:% stance leg, pelvis, and swing leg.V = Jp * [u1;u2];bigM = diag([Ml Ml Il Mp Mp Ip Ml Ml Il]); % diagonal matrix of segment masses% Notice that bigM * Xdotold is the momentum of the system before impact% Let's also put together a matrix of constraints for when the % stance foot is on the ground. We want the segments to be% stuck together, and we want the leading foot to be stuck to the% ground. Set up a constraint Jacobian so that the% constraints are satisfied with Jc * Xdot = 0Jc = [ 1  0  0*c1   0  0  0  0  0      0   ;  % stance foot glued to ground, x       0  1  0*s1   0  0  0  0  0      0   ;  % stance foot glued to ground, y      -1  0 (L)*c1  1  0  0  0  0      0   ;  % stance leg to pelvis, x       0 -1 (L)*s1  0  1  0  0  0      0   ;  % stance leg to pelvis, y       0  0   -1    0  0  1  0  0      0   ;  % pelvis rotates with leg       0  0    0   -1  0  0  1  0 -(L)*c2;  % swing leg to pelvis, x       0  0    0    0 -1  0  0  1 -(L)*s2]; % swing leg to pelvis, y% also need derivative of constraint Jacobian:Jcdot = [ 0 0  0*u1      0 0 0 0 0      0       ; % stance foot glued to ground, x          0 0  0*u1      0 0 0 0 0      0       ; % stance foot glued to ground, y          0 0 -(L)*s1*u1 0 0 0 0 0      0       ; % stance leg to pelvis, x          0 0  (L)*c1*u1 0 0 0 0 0      0       ; % stance leg to pelvis, y          0 0      0       0 0 0 0 0    0       ; % pelvis rotates with leg          0 0      0       0 0 0 0 0   (L)*s2*u2;  % swing leg to pelvis, x          0 0      0       0 0 0 0 0  -(L)*c2*u2]; % swing leg to pelvis, y       % M * Vdot = Jc'*lambda + Fext% Jc* Vdot + Jcdot*V = 0% The forces applied here include gravity as the only external force:Fext = [Ml*g*sg; -Ml*g*cg; 0; Mp*g*sg; -Mp*g*cg; 0; Ml*g*sg; -Ml*g*cg; 0];% Note: type Jc*Jp to demonstrate that Jp is in nullspace of Jc.%Jc*Jp% The constraint forces are equal to Jc*lambda, included in the big matrix% We will solve a linear system where the right-hand side consists of the% external forces and the equilibrium needed for J*Vdot:rhs = [Fext; -Jcdot*V];  blockmatrix = [bigM Jc'; Jc zeros(7,7)];blocklhs = blockmatrix \ rhs; % solve for the new velocities% blocklhs contains the new Xdots, plus the constraint forcesVdot = blocklhs(1:9);lambdas =  -blocklhs(10:end);% The Xdots of most interest are the angular velocities of % the trailing and leading legsudot(1) = Vdot(3);udot(2) = Vdot(9);xdot = [u1; u2; udot(1); udot(2)]; % form the state-derivativeend % fwalksimpwalk2Jc%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%function xdot = fsimpwalk2Jp(t, x, optparms)% state derivative function for a simple walker with point masses% using embedded pose Jacobian method% This is an alternate version, demonstrating how the equations can% be derived accurately for the limit as (m/M) -> 0if nargin == 3 % parameters fed in as third argument    parms = optparms;end            % otherwise expect parms to be in scope% Parameters: M L g gamma mM = parms.M; L = parms.L; g = parms.g; m = parms.m;gamma = parms.gamma; % State assignmentsq1 = x(1); q2 = x(2); qdot = x(3:4); u1 = x(3); u2 = x(4);c1 = cos(q1); c2 = cos(q2); s1 = sin(q1); s2 = sin(q2);cg = cos(gamma); sg = sin(gamma);% big mass matrix for%   MM * Vdot = Fnc + Fc  where Fnc = non-constraint forces,%                               Fc  = constraint forces%                               Vdot = [vx1, vy1, th1dot, vx2, vy2, th2dot]MM = diag([M, M, 0, m, m, 0]); Fnc = [M*g*sg -M*g*cg 0 m*g*sg -m*g*cg 0]'; % gravity is non-constraint force% Pose Jacobian to map qdots into velocities%   V = J*qdot and Vdot = J*qddot + Jdot*qdotJ = [-L*c1 0; -L*s1 0; 1 0; -L*c1 L*c2; -L*s1 L*s2; 0 1];Jdot = [L*s1*u1 0; -L*c1*u1 0; 0 0;   L*s1*u1 -L*s2*u2; -L*c2*u1 L*c2*u2; 0 0];massmatrix = J'*MM*J;righthandside = J'*Fnc - J'*MM*Jdot*qdot;qddot = massmatrix \ righthandside;xdot = [qdot; qddot];end % state derivative function%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%function animatesimpwalk2(x,varargin)% ANIMATESIMPWALK2 for the simplest walking simulation%% animatesimpwalk2(x [,parms]) with a list of state vectors (each in a row)%   equally spaced in time, animates a single step. Parameters struct%   parms must be in scope, or entered as optional argument.%% animatesimpwalk2(x, numsteps [,parms]) animates the single step given %   in x repetitively by a number of times specified by the scalar numsteps%% animatesimpwalk2(x, steplist [,parms]) animates a list of state vectors over %   multiple steps, where steplist is the list of the number of state%   vectors (time steps) in each step.%% To have the program save each frame as an encapsulated Postscript file,%   use animatesimpwalk2(x, numstepsORsteplist [,parms], 1)% x should normally contain one full step of the states, [q1 q2 u1 u2] %   arranged in rows.  numsteps is the # of steps to walk (the states in x are%   repeated automatically for numsteps > 1).  An alternative way to%   call animatewalk is if x contains multiple steps, then numsteps%   can be a vector containing the starting indices for each of the%   multiple steps.printflag = 0;  % default to not saving/printing framesnumsteps = 2;   % default to 2 steps animationif nargin == 1     % expect parms to be in enclosing scopeelseif nargin == 2 % figure out if parms or numsteps    if isstruct(varargin{1}) % parms struct        parms = varargin{1};    else        numsteps = varargin{1};        % parms should be scope    endelseif nargin == 3  % figure out if parms or printflag    numsteps = varargin{1};    if isstruct(varargin{2}) % parms struct        parms = varargin{2};    else        printflag = varargin{2};    endelseif nargin == 4   % printflag is given    numsteps = varargin{1};    parms = varargin{2};    printflag = varargin{3};end% Next need to figure out whether numsteps or steplistxlen = length(x);if length(numsteps) > 1 %  numsteps is a list   steplist = numsteps; % steplist is list of step time-lengths  numsteps = length(steplist); % numsteps is just a count of steps  endindex = cumsum(steplist); % within x, index the start and end  startindex = [1 endindex+1]; % of each stepelse % numsteps is just a scalar, so make our own steplist  steplist = [xlen repmat(xlen-1, 1, numsteps-1)];  endindex = repmat(xlen, numsteps, 1);  startindex = repmat(1,numsteps,1); % extra frameend% Now numsteps contains the number of steps, steplist% contains the number of frames in each step, and% startindex and endindex contain indices for each step  % Parameters: M L g gamma M = parms.M; L = parms.L; g = parms.g;gamma = parms.gamma; footn = 10; % arc foot will be drawn as this many line segmentsalpha = 0.3; % with range of +/-alpha angleR = 0;      % simplest model has no arc footpausetime = 0.5; % pause this much time between animation framesdebg = 0;  % set to 1 to display intermediate information% Now numsteps contains the number of steps, steplist% contains the number of frames in each step, and% startindex and endindex contain indices for each step% Estimate range of walkingdistance = 2*numsteps*R*x(1,1)+(numsteps+1)*((L-R)*abs(sin(x(1,1))-sin(x(1,2))));buffer = 0.1;xlimit = [-buffer distance+buffer]-(L-R)*abs(sin(x(1,1))-sin(x(1,2))); ylimit = [-0.05 1.35];aang = pi/6; scale = 0.02; scale2 = 2; vx2 = 0.4; vy2 = 1.2;% A foot% foot starts at -sin(a),cos(a)% and goes to sin(a),cos(a)footang = linspace(-alpha*1.1, alpha*1.1, footn);footxy = R*[sin(footang); -cos(footang)];% Initializeclf; q1 = x(1,1); q2 = x(1,2); u1 = x(1,3);contactpoint = -q1*R;Rot1 = [cos(q1) -sin(q1); sin(q1) cos(q1)];Rot2 = [cos(q2) -sin(q2); sin(q2) cos(q2)];footx1 = Rot1(1,:)*footxy + contactpoint; footy1 = Rot1(2,:)*footxy + R;legsxy = [0  -sin(q1)  -sin(q1)+sin(q2);  0   cos(q1)   cos(q1)-cos(q2)];legsx = legsxy(1,:) + contactpoint + R*sin(q1);legsy = legsxy(2,:) + R - R*cos(q1);       footx2 = Rot2(1,:)*footxy + legsx(3) - R*sin(q2);footy2 = Rot2(2,:)*footxy + legsy(3) + R*cos(q2);pcm = legsxy(:,2) + [contactpoint+R*sin(q1);R-R*cos(q1)];vcm = [-u1*(R + (L-R)*cos(q1)); -u1*(L-R)*sin(q1)];velang = atan2(vcm(2),vcm(1));velx = [0 vcm(1) vcm(1)-scale*cos(velang+aang) NaN vcm(1) vcm(1)-scale*cos(velang-aang)]+pcm(1);vely = [0 vcm(2) vcm(2)-scale*sin(velang+aang) NaN vcm(2) vcm(2)-scale*sin(velang-aang)]+pcm(2);velx2 = scale2*[0 vcm(1) vcm(1)-scale*cos(velang+aang) NaN vcm(1) vcm(1)-scale*cos(velang-aang)]+vx2;vely2 = scale2*[0 vcm(2) vcm(2)-scale*sin(velang+aang) NaN vcm(2) vcm(2)-scale*sin(velang-aang)]+vy2;set(gcf, 'color', [1 1 1]); set(gca,'DataAspectRatio',[1 1 1],'Visible','off','NextPlot','Add','XLim',xlimit,'YLim',ylimit);hf1 = line(footx1,footy1,'Marker','.','MarkerSize',20); hf2 = line(footx2,footy2,'Marker','.','MarkerSize',20);hlegs = line(legsx,legsy,'LineWidth',3);hvel = line(velx,vely,'color','m','LineWidth',2);hpelv = plot(legsx(2),legsy(2),'.','MarkerSize',30);hgnd = line(xlimit,[0 0]-.01,'color',[0 0 0],'linewidth',2);%hvel2 = line(velx2,vely2,'color','m','LineWidth',2);th1old = q1; cntr = 1;for j = 1:numsteps  for i = startindex(j):endindex(j)    q1 = x(i,1); q2 = x(i,2);    contactpoint = contactpoint - (q1-th1old)*R; % roll forward a little    th1old = q1;    Rot1 = [cos(q1) -sin(q1); sin(q1) cos(q1)];    Rot2 = [cos(q2) -sin(q2); sin(q2) cos(q2)];        footx1 = Rot1(1,:)*footxy + contactpoint; footy1 = Rot1(2,:)*footxy + R;    legsxy = [0  -sin(q1)  -sin(q1)+sin(q2);              0   cos(q1)   cos(q1)-cos(q2)];    legsx = legsxy(1,:) + contactpoint + R*sin(q1);    legsy = legsxy(2,:) + R - R*cos(q1);           footx2 = Rot2(1,:)*footxy + legsx(3) - R*sin(q2);    footy2 = Rot2(2,:)*footxy + legsy(3) + R*cos(q2);        pcm = legsxy(:,2) + [contactpoint+R*sin(q1);R-R*cos(q1)];    vcm = [-u1*(R + (L-R)*cos(q1)); -u1*(L-R)*sin(q1)];    velang = atan2(vcm(2),vcm(1));    velx = [0 vcm(1) vcm(1)-scale*cos(velang+aang) NaN vcm(1) vcm(1)-scale*cos(velang-aang)]+pcm(1);    vely = [0 vcm(2) vcm(2)-scale*sin(velang+aang) NaN vcm(2) vcm(2)-scale*sin(velang-aang)]+pcm(2);    velx2 = scale2*[0 vcm(1) vcm(1)-scale*cos(velang+aang) NaN vcm(1) vcm(1)-scale*cos(velang-aang)]+vx2;    vely2 = scale2*[0 vcm(2) vcm(2)-scale*sin(velang+aang) NaN vcm(2) vcm(2)-scale*sin(velang-aang)]+vy2;        set(hf1,'Xdata',footx1,'Ydata',footy1);    set(hf2,'Xdata',footx2,'Ydata',footy2);    set(hlegs,'Xdata',legsx,'Ydata',legsy);    set(hvel,'Xdata',velx,'Ydata',vely);    set(hpelv,'Xdata',legsx(2),'Ydata',legsy(2));    if 0    if i==1 & j > 1  % stick velocity arrow      hveli=line(velx2,vely2,'color','m','LineWidth',2);      oldx = get(hvelo,'xdata'); oldy = get(hvelo,'ydata');      hsang = atan2(vely2(2)-oldy(2),velx2(2)-oldx(2));      velxh = [oldx(2) velx2(2) velx2(2)-scale2*scale*cos(hsang+aang) NaN velx2(2) velx2(2)-scale2*scale*cos(hsang-aang)];    	velyh = [oldy(2) vely2(2) vely2(2)-scale2*scale*sin(hsang+aang) NaN vely2(2) vely2(2)-scale2*scale*sin(hsang-aang)];    		hvelhs = line(velxh,velyh,'color','r','Linewidth',2);        end    end    drawnow;     if ~printflag      pause(0.05)    else      print('-depsc2',sprintf('walk%02d',cntr));    end    if debg, pause, end;    cntr = cntr + 1;  end  contactpoint = contactpoint - (L-R)*(sin(q1)-sin(q2)); th1old = q2;endend % animatesimpwalk2%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%function [xstar, cnvrg] = findroot(f, x0, frparms)% FINDROOT  Finds the root of a vector function, with vector-valued x0.%  % xstar = findroot(f, x0) performs a Newton search and returns xstar,%   the root of the function f, starting with initial guess x0. The%   function will typically be expressed with a function handle, e.g. %   @f.%%   Optional input findroot(f, x0, frparms) includes parameters structure,%   with fields dxtol (smallest allowable dx) and maxiter (max #%   iterations).%%   Optional second output [xstar, cnvrg] = findroot... signals%   successful convergence. It is set to %   false if maximum iterations is exceeded.if nargin < 3    frparms.dxtol = 1e-6;      % default tolerance for min change in x    frparms.dftol = 1e-6;      % default tolerance for min change in f    frparms.maxiter = 1000;    % allow max of 1000 iterations before quitting    frparms.finitediffdx = []; % finite differencing step sizeend% We will take steps to improve on x, while monitoring% the change dx, and stopping when it becomes smalldx = Inf;          % initial dx is largeiter = 0;          % count the iterations we go throughx = x0(:);         % start at this initial guess (treat x as a column vector)fprevious = f(x0); % use to compare changes in function valuedf = Inf;          % change in f is initialized as large% Loop through the refinements, checking to make sure that x and f% change by some minimal amount, and that we haven't exceeded% the maximum number of iterationswhile max(abs(dx)) >= frparms.dxtol & max(abs(df)) >= frparms.dftol & ...        iter <= frparms.maxiter  % Here is the main Newton step  J = fjacobian(f, x, frparms.finitediffdx); % This is the slope  dx = J\(0 - f(x));                 % and this is the correction to x  x = x + dx;  % Update information about changes  iter = iter + 1;  df = f(x) - fprevious;  fprevious = f(x);endxstar = x; % use the latest, best guesscnvrg = true;if iter > frparms.maxiter % we probably didn't find a good solution  warning('Maximum iterations exceeded in findroot');  cnvrg = false;endif size(x0,2) > 1   % x0 was given to us as a row vector    xstar = xstar'; % so return xstar in the same shapeend    end % findroot%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%function dfdx = fjacobian(f, x0, dx)% FJACOBIAN   Computes Jacobian (partial derivative) of function%% dfdx = fjacobian(@f, x0 [, dx])%%   Uses finite differences to compute partial derivative of vector %   function f evaluated at vector x0. %   Optional argument dx specifies finite difference%   step. Note that argument f should typically be entered as a%   function handle, e.g. @f.%%   When dx is not given or empty, a default of 1e-6 is used.if nargin < 3 || isempty(dx)dx = 1e-6;endf0 = f(x0);J = zeros(length(f0), length(x0));for i = 1:length(x0)xperturbed = x0;xperturbed(i) = xperturbed(i) + dx;df(:,i) = f(xperturbed) - f0;enddfdx = df / dx;end % fjacobian function%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%end % outer function