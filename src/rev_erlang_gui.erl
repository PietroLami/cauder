-module(rev_erlang_gui).
-export([setup_gui/0]).

-include("rev_erlang.hrl").
-include("rev_erlang_gui.hrl").
-include_lib("wx/include/wx.hrl").

setup_gui() ->
  Server = wx:new(),
  Frame = wxFrame:new(Server, -1, ?APP_STRING, [{size, ?FRAME_SIZE_INIT}]),
  ref_start(),
  ref_add(?FILE_PATH, "."),
  ref_add(?STATUS, #status{}),
  ref_add(?FRAME, Frame),
  setupMenu(),
  wxFrame:createStatusBar(Frame, [{id, ?STATUS_BAR}]),
  wxEvtHandler:connect(Frame, close_window),
  wxEvtHandler:connect(Frame, command_button_clicked),
  wxEvtHandler:connect(Frame, command_menu_selected),
  wxEvtHandler:connect(Frame, command_text_updated),
  setupMainPanel(Frame),
  wxFrame:show(Frame),
  loop(),
  utils_gui:stop_refs(),
  ref_stop().

setupMainPanel(Parent) ->
  MainPanel = wxPanel:new(Parent),
  MainSizer = wxBoxSizer:new(?wxHORIZONTAL),
  SizerFlags = [{proportion, 1}, {flag, ?wxEXPAND}],

  LeftPanel = wxPanel:new(MainPanel),
  LeftSizer = setupLeftSizer(LeftPanel),
  wxWindow:setSizerAndFit(LeftPanel, LeftSizer),

  RightPanel = wxPanel:new(MainPanel),
  RightSizer = setupRightSizer(RightPanel),
  wxWindow:setSizerAndFit(RightPanel, RightSizer),

  wxSizer:add(MainSizer, LeftPanel, SizerFlags),
  wxSizer:add(MainSizer, RightPanel, SizerFlags),
  wxWindow:setSizer(MainPanel, MainSizer),
  MainPanel.

setupLeftSizer(Parent) ->
  Notebook = wxNotebook:new(Parent, ?LEFT_NOTEBOOK),
  ref_add(?LEFT_NOTEBOOK, Notebook),
  CodePanel = setupCodePanel(Notebook),
  StatePanel = setupStatePanel(Notebook),
  wxNotebook:addPage(Notebook, CodePanel, "Code"),
  wxNotebook:addPage(Notebook, StatePanel, "State"),
  % wxNotebook:layout(Notebook),
  LeftSizer = wxBoxSizer:new(?wxVERTICAL),
  SizerFlags = [{proportion, 1}, {flag, ?wxEXPAND}],
  wxSizer:add(LeftSizer, Notebook, SizerFlags),
  LeftSizer.

setupCodePanel(Parent) ->
  CodePanel = wxPanel:new(Parent),
  CodeText = wxTextCtrl:new(CodePanel, ?CODE_TEXT,
                             [{style,?wxTE_MULTILINE bor ?wxTE_READONLY}]),
  ref_add(?CODE_TEXT,CodeText),


  FundefStaticText = wxStaticText:new(CodePanel, ?wxID_ANY, "Funs: "),
  FunChoice = wxChoice:new(CodePanel, ?wxID_ANY),
  ref_add(?FUN_CHOICE,FunChoice),
  InputStaticText = wxStaticText:new(CodePanel, ?wxID_ANY, "Input args: "),
  InputTextCtrl = wxTextCtrl:new(CodePanel, ?INPUT_TEXT,
                                 [{style, ?wxBOTTOM},
                                  {value, ""}]),
  ref_add(?INPUT_TEXT,InputTextCtrl),
  StartButton = wxButton:new(CodePanel, ?START_BUTTON,
                             [{label, "START"}]),
  ref_add(?START_BUTTON,StartButton),
  wxButton:disable(StartButton),

  CodeSizer = wxBoxSizer:new(?wxVERTICAL),
  InputSizer = wxBoxSizer:new(?wxHORIZONTAL),
  ref_add(?INPUT_SIZER, InputSizer),
  BorderSizer = wxBoxSizer:new(?wxVERTICAL),
  SizerFlags = [{proportion, 1}, {flag, ?wxEXPAND}],

  wxSizer:add(CodeSizer, CodeText, SizerFlags),
  wxSizer:addSpacer(CodeSizer, 10),
  wxSizer:add(CodeSizer, InputSizer, [{proportion, 0}, {flag, ?wxEXPAND}]),

  wxSizer:add(InputSizer, FundefStaticText),
  wxSizer:add(InputSizer, FunChoice),
  wxSizer:addSpacer(InputSizer, 10),
  wxSizer:add(InputSizer, InputStaticText),
  wxSizer:add(InputSizer, InputTextCtrl, SizerFlags),
  wxSizer:addSpacer(InputSizer, 10),
  wxSizer:add(InputSizer, StartButton, [{flag, ?wxALIGN_RIGHT}]),

  wxSizer:add(BorderSizer, CodeSizer, [{flag, ?wxALL bor ?wxEXPAND},
                                       {proportion, 1}, {border, 10}]),
  wxWindow:setSizer(CodePanel, BorderSizer),
  CodePanel.

 setupStatePanel(Parent) ->
  StatePanel = wxPanel:new(Parent),
  StateText = wxTextCtrl:new(StatePanel, ?STATE_TEXT,
                             [{style, ?wxTE_MULTILINE bor ?wxTE_READONLY}]),
  ref_add(?STATE_TEXT, StateText),
  StateSizer = wxBoxSizer:new(?wxVERTICAL),
  BorderSizer = wxBoxSizer:new(?wxVERTICAL),
  SizerFlags = [{proportion, 1}, {flag, ?wxEXPAND}],
  wxSizer:add(StateSizer, StateText, SizerFlags),
  wxSizer:add(BorderSizer, StateSizer, [{flag, ?wxALL bor ?wxEXPAND},
                                        {proportion, 1}, {border, 10}]),
  wxWindow:setSizer(StatePanel, BorderSizer),
  StatePanel.

setupTracePanel(Parent) ->
  TracePanel = wxPanel:new(Parent),
  TraceText = wxTextCtrl:new(TracePanel, ?TRACE_TEXT,
                             [{style, ?wxTE_MULTILINE bor ?wxTE_READONLY}]),
  ref_add(?TRACE_TEXT, TraceText),
  TraceSizer = wxBoxSizer:new(?wxVERTICAL),
  BorderSizer = wxBoxSizer:new(?wxVERTICAL),
  SizerFlags = [{proportion, 1}, {flag, ?wxEXPAND}],
  wxSizer:add(TraceSizer, TraceText, SizerFlags),
  wxSizer:add(BorderSizer, TraceSizer, [{flag, ?wxALL bor ?wxEXPAND},
                                        {proportion, 1}, {border, 10}]),
  wxWindow:setSizer(TracePanel, BorderSizer),
  TracePanel.

setupRightSizer(Parent) ->
  Notebook = wxNotebook:new(Parent, ?RIGHT_NOTEBOOK),
  BottomNotebook = wxNotebook:new(Parent, ?RIGHT_BOTTOM_NOTEBOOK),
  ref_add(?RIGHT_NOTEBOOK, Notebook),
  ref_add(?RIGHT_BOTTOM_NOTEBOOK, BottomNotebook),
  ManuPanel = setupManualPanel(Notebook),
  % SemiPanel = setupSemiPanel(Notebook),
  AutoPanel = setupAutoPanel(Notebook),
  wxNotebook:addPage(Notebook, ManuPanel, "Manual"),
  % wxNotebook:addPage(Notebook, SemiPanel, "Semi"),
  wxNotebook:addPage(Notebook, AutoPanel, "Automatic"),
  % wxNotebook:layout(Notebook),
  TracePanel = setupTracePanel(BottomNotebook),
  wxNotebook:addPage(BottomNotebook, TracePanel, "Trace"),
  RightSizer = wxBoxSizer:new(?wxVERTICAL),
  SizerFlags = [{proportion, 0}, {flag, ?wxEXPAND}],
  BottomSizerFlags = [{proportion, 1}, {flag, ?wxEXPAND}],
  wxSizer:add(RightSizer, Notebook, SizerFlags),
  wxSizer:add(RightSizer, BottomNotebook, BottomSizerFlags),
  RightSizer.

setupManualPanel(Parent) ->
  ManuPanel = wxPanel:new(Parent),
  PidStaticText = wxStaticText:new(ManuPanel, ?wxID_ANY, "Pid/MsgId:"),
  PidTextCtrl = wxTextCtrl:new(ManuPanel, ?PID_TEXT, [{style, ?wxBOTTOM}]),
  ref_add(?PID_TEXT, PidTextCtrl),

  ForwIntButton = wxButton:new(ManuPanel, ?FORW_INT_BUTTON,
                               [{label, "Seq"}]),
  ForwSchButton = wxButton:new(ManuPanel, ?FORW_SCH_BUTTON,
                                [{label, "Sched"}]),
  BackIntButton = wxButton:new(ManuPanel, ?BACK_INT_BUTTON,
                               [{label, "Seq"}]),
  BackSchButton = wxButton:new(ManuPanel, ?BACK_SCH_BUTTON,
                                [{label, "Sched"}]),
  wxButton:disable(ForwIntButton),
  wxButton:disable(ForwSchButton),
  wxButton:disable(BackIntButton),
  wxButton:disable(BackSchButton),
  ref_add(?FORW_INT_BUTTON, ForwIntButton),
  ref_add(?FORW_SCH_BUTTON, ForwSchButton),
  ref_add(?BACK_INT_BUTTON, BackIntButton),
  ref_add(?BACK_SCH_BUTTON, BackSchButton),

  ManuSizer = wxBoxSizer:new(?wxVERTICAL),
  ProcSizer = wxBoxSizer:new(?wxHORIZONTAL),
  ForwardSizer = wxStaticBoxSizer:new(?wxHORIZONTAL, ManuPanel,
                                      [{label, "Forward rules"}]),
  BackwardSizer = wxStaticBoxSizer:new(?wxHORIZONTAL, ManuPanel,
                                      [{label, "Backward rules"}]),
  ButtonSizer = wxBoxSizer:new(?wxVERTICAL),
  BorderSizer = wxBoxSizer:new(?wxVERTICAL),

  wxSizer:add(ManuSizer, ProcSizer),
  wxSizer:addSpacer(ManuSizer, 10),
  wxSizer:add(ManuSizer, ButtonSizer),

  wxSizer:add(ProcSizer, PidStaticText, [{flag, ?wxCENTRE}]),
  wxSizer:add(ProcSizer, PidTextCtrl, [{flag, ?wxCENTRE}]),
  
  wxSizer:add(ForwardSizer, ForwIntButton),
  wxSizer:addSpacer(ForwardSizer, 5),
  wxSizer:add(ForwardSizer, ForwSchButton),
  wxSizer:add(BackwardSizer, BackIntButton),
  wxSizer:addSpacer(BackwardSizer, 5),
  wxSizer:add(BackwardSizer, BackSchButton),

  wxSizer:add(ButtonSizer, ForwardSizer, [{flag, ?wxALIGN_CENTER_HORIZONTAL}]),
  wxSizer:addSpacer(ButtonSizer, 5),
  wxSizer:add(ButtonSizer, BackwardSizer, [{flag, ?wxALIGN_CENTER_HORIZONTAL}]),

  wxSizer:add(BorderSizer, ManuSizer, [{flag, ?wxALL bor ?wxALIGN_CENTER_HORIZONTAL}, {border, 10}]),
  wxWindow:setSizer(ManuPanel, BorderSizer),
  ManuPanel.

% setupSemiPanel(Parent) ->
%   SemiPanel = wxPanel:new(Parent),
%   SemiPanel.

setupAutoPanel(Parent) ->
  AutoPanel = wxPanel:new(Parent),
  StepStaticText = wxStaticText:new(AutoPanel, ?wxID_ANY, "Steps:"),
  RollPidStaticText = wxStaticText:new(AutoPanel, ?wxID_ANY, "Pid:"),
  RollStepStaticText = wxStaticText:new(AutoPanel, ?wxID_ANY, "Steps:"),
  StepTextCtrl = wxTextCtrl:new(AutoPanel, ?STEP_TEXT, [{style,?wxBOTTOM}]),
  RollPidTextCtrl = wxTextCtrl:new(AutoPanel, ?ROLL_PID_TEXT, [{style,?wxBOTTOM},
                                                               {size, {40, -1}}]),
  RollStepTextCtrl = wxTextCtrl:new(AutoPanel, ?ROLL_STEP_TEXT, [{style,?wxBOTTOM},
                                                                 {size, {40, -1}}]),
  ref_add(?STEP_TEXT, StepTextCtrl),
  ref_add(?ROLL_PID_TEXT, RollPidTextCtrl),
  ref_add(?ROLL_STEP_TEXT, RollStepTextCtrl),
  HorizontalLine = wxStaticLine:new(AutoPanel, [{style, ?wxLI_HORIZONTAL},
                                                {size, {200, -1}}]),
  HorizontalLine2 = wxStaticLine:new(AutoPanel, [{style, ?wxLI_HORIZONTAL},
                                                {size, {200, -1}}]),
  ForwardButton = wxButton:new(AutoPanel, ?FORWARD_BUTTON,
                               [{label, "Forward"}]),
  BackwardButton = wxButton:new(AutoPanel, ?BACKWARD_BUTTON,
                                [{label, "Backward"}]),
  NormalizeButton = wxButton:new(AutoPanel, ?NORMALIZE_BUTTON,
                                [{label, "Normalize"}]),
  RollButton = wxButton:new(AutoPanel, ?ROLL_BUTTON,
                                [{label, "Roll"},
                                 {size, {40, -1}}]),
  wxButton:disable(ForwardButton),
  wxButton:disable(BackwardButton),
  wxButton:disable(NormalizeButton),
  %wxButton:disable(RollButton),
  ref_add(?FORWARD_BUTTON, ForwardButton),
  ref_add(?BACKWARD_BUTTON, BackwardButton),
  ref_add(?NORMALIZE_BUTTON, NormalizeButton),
  ref_add(?ROLL_BUTTON, RollButton),

  AutoSizer = wxBoxSizer:new(?wxVERTICAL),
  StepSizer = wxBoxSizer:new(?wxHORIZONTAL),
  StepButtonSizer = wxBoxSizer:new(?wxHORIZONTAL),
  SchedButtonSizer = wxBoxSizer:new(?wxHORIZONTAL),
  RollSizer = wxBoxSizer:new(?wxHORIZONTAL),
  BorderSizer = wxBoxSizer:new(?wxVERTICAL),

  wxSizer:add(AutoSizer, StepSizer, [{flag, ?wxALIGN_CENTER_HORIZONTAL}]),
  wxSizer:addSpacer(AutoSizer, 15),
  wxSizer:add(AutoSizer, StepButtonSizer, [{flag, ?wxALIGN_CENTER_HORIZONTAL}]),
  wxSizer:add(AutoSizer, HorizontalLine, [{flag, ?wxTOP bor ?wxBOTTOM},
                                          {border, 15}]),
  wxSizer:add(AutoSizer, SchedButtonSizer, [{flag, ?wxALIGN_CENTER_HORIZONTAL}]),
  wxSizer:add(AutoSizer, HorizontalLine2, [{flag, ?wxTOP bor ?wxBOTTOM},
                                          {border, 15}]),
  wxSizer:add(AutoSizer, RollSizer, [{flag, ?wxALIGN_CENTER_HORIZONTAL}]),

  wxSizer:add(StepSizer, StepStaticText),
  wxSizer:add(StepSizer, StepTextCtrl),

  wxSizer:add(StepButtonSizer, ForwardButton),
  wxSizer:addSpacer(StepButtonSizer, 5),
  wxSizer:add(StepButtonSizer, BackwardButton),

  wxSizer:add(SchedButtonSizer, NormalizeButton),

  wxSizer:add(RollSizer, RollPidStaticText),
  wxSizer:add(RollSizer, RollPidTextCtrl),
  wxSizer:addSpacer(RollSizer, 5),
  wxSizer:add(RollSizer, RollStepStaticText),
  wxSizer:add(RollSizer, RollStepTextCtrl),
  wxSizer:addSpacer(RollSizer, 5),
  wxSizer:add(RollSizer, RollButton),

  wxSizer:add(BorderSizer, AutoSizer, [{flag, ?wxALL bor ?wxALIGN_CENTER_HORIZONTAL}, {border, 10}]),
  wxWindow:setSizer(AutoPanel, BorderSizer),
  AutoPanel.

setupMenu() ->
  MenuBar = wxMenuBar:new(),
  File = wxMenu:new(),
  View = wxMenu:new(),
  Help = wxMenu:new(),
  wxMenuBar:append(MenuBar, File, "&File"),
  wxMenuBar:append(MenuBar, View, "&View"),
  wxMenuBar:append(MenuBar, Help, "&Help"),
  wxMenu:append(File, ?OPEN,     "Open\tCtrl-O"),
  wxMenu:append(File, ?EXIT,     "Quit\tCtrl-Q"),
  wxMenu:append(View, ?ZOOM_IN,  "Zoom In\tCtrl-+"),
  wxMenu:append(View, ?ZOOM_OUT, "Zoom Out\tCtrl--"),
  wxMenu:append(Help, ?ABOUT,    "About"),
  Frame = ref_lookup(?FRAME),
  wxFrame:setMenuBar(Frame, MenuBar).

loadFile(File) ->
  Frame = ref_lookup(?FRAME),
  case compile:file(File, [to_core,binary]) of
    {ok, _, CoreForms} ->
      NoAttsCoreForms = cerl:update_c_module(CoreForms,
                                             cerl:module_name(CoreForms),
                                             cerl:module_exports(CoreForms),
                                             [],
                                             cerl:module_defs(CoreForms)),
      Stripper = fun(Tree) -> cerl:set_ann(Tree, []) end,
      CleanCoreForms = cerl_trees:map(Stripper, NoAttsCoreForms),
      FunDefs = cerl:module_defs(CleanCoreForms),
      CodeText = ref_lookup(?CODE_TEXT),
      wxTextCtrl:setValue(CodeText, core_pp:format(CleanCoreForms)),
      Status = ref_lookup(?STATUS),
      ref_add(?STATUS, Status#status{loaded = {true, FunDefs}}),
      LeftNotebook = ref_lookup(?LEFT_NOTEBOOK),
      wxNotebook:setSelection(LeftNotebook, ?PAGEPOS_CODE),
      utils_gui:set_choices(utils:moduleNames(CleanCoreForms)),
      InputSizer = ref_lookup(?INPUT_SIZER),
      wxSizer:layout(InputSizer),
      StartButton = ref_lookup(?START_BUTTON),
      wxButton:enable(StartButton),
      wxFrame:setStatusText(Frame, "Loaded file " ++ File);
    _Other ->
      wxFrame:setStatusText(Frame, "Error: Could not compile file " ++ File)
  end.

openDialog(Parent) ->
  Caption = "Select an Erlang file",
  Wildcard = "Erlang source|*.erl| All files|*",
  DefaultDir = ref_lookup(?FILE_PATH),
  DefaultFile = "",
  Dialog = wxFileDialog:new(Parent, [{message, Caption},
                                     {defaultDir, DefaultDir},
                                     {defaultFile, DefaultFile},
                                     {wildCard, Wildcard},
                                     {style, ?wxFD_OPEN bor
                                          ?wxFD_FILE_MUST_EXIST}]),
  case wxDialog:showModal(Dialog) of
      ?wxID_OK ->
        File = wxFileDialog:getPaths(Dialog),
        loadFile(File);
      _Other -> continue
  end,
  wxDialog:destroy(Dialog).

zoomIn() ->
  CodeText = ref_lookup(?CODE_TEXT),
  StateText = ref_lookup(?STATE_TEXT),
  Font = wxTextCtrl:getFont(CodeText),
  CurFontSize = wxFont:getPointSize(Font),
  NewFontSize = utils_gui:next_font_size(CurFontSize),
  NewFont = wxFont:new(),
  wxFont:setPointSize(NewFont, NewFontSize),
  wxTextCtrl:setFont(CodeText, NewFont),
  wxTextCtrl:setFont(StateText, NewFont).

zoomOut() ->
  CodeText = ref_lookup(?CODE_TEXT),
  StateText = ref_lookup(?STATE_TEXT),
  Font = wxTextCtrl:getFont(CodeText),
  CurFontSize = wxFont:getPointSize(Font),
  NewFontSize = utils_gui:prev_font_size(CurFontSize),
  NewFont = wxFont:new(),
  wxFont:setPointSize(NewFont, NewFontSize),
  wxTextCtrl:setFont(CodeText, NewFont),
  wxTextCtrl:setFont(StateText, NewFont).

init_system(Fun, Args) ->
  Proc = #proc{pid = cerl:c_int(1),
               exp = cerl:c_apply(Fun, Args)},
  Procs = [Proc],
  System = #sys{procs = Procs},
  ref_add(?SYSTEM, System),
  Status = ref_lookup(?STATUS),
  NewStatus = Status#status{running = true},
  ref_add(?STATUS, NewStatus).

start(Fun,Args) ->
  Status = ref_lookup(?STATUS),
  #status{loaded = {true, FunDefs}} = Status,
  utils_gui:stop_refs(),
  rev_erlang:start_refs(FunDefs),
  init_system(Fun, Args),
  refresh(),
  LeftNotebook = ref_lookup(?LEFT_NOTEBOOK),
  wxNotebook:setSelection(LeftNotebook, ?PAGEPOS_STATE),
  {FunName, FunArity} = cerl:var_name(Fun),
  StartString = "Started system with " ++
                atom_to_list(FunName) ++ "/" ++
                integer_to_list(FunArity) ++ " fun application!",
  utils_gui:update_status_text(StartString).

refresh_buttons(Options) ->
  PidTextCtrl = ref_lookup(?PID_TEXT),
  PidText = wxTextCtrl:getValue(PidTextCtrl),
  ManualButtons = lists:seq(?FORW_INT_BUTTON, ?BACK_SCH_BUTTON),
  ?LOG("full options: " ++ ?TO_STRING(utils_gui:sort_opts(Options))),
  case string:to_integer(PidText) of
    {error, _} ->
      utils_gui:disable_rule_buttons(ManualButtons);
    {PidInt, _} ->
      FiltOpts = utils:filter_options(Options, PidInt),
      FiltButtons = lists:map(fun utils_gui:option_to_button_label/1, FiltOpts),
      [utils_gui:set_button_label_if(Button, FiltButtons) ||
                               Button <- ManualButtons]
  end,
  HasFwdOptions = utils:has_fwd(Options),
  HasBwdOptions = utils:has_bwd(Options),
  HasNormOptions = utils:has_norm(Options),
  utils_gui:set_ref_button_if(?FORWARD_BUTTON, HasFwdOptions),
  utils_gui:set_ref_button_if(?BACKWARD_BUTTON, HasBwdOptions),
  utils_gui:set_ref_button_if(?NORMALIZE_BUTTON, HasNormOptions).

disable_all_buttons() ->
  ForwIntButton   = ref_lookup(?FORW_INT_BUTTON),
  ForwSchButton   = ref_lookup(?FORW_SCH_BUTTON),
  BackIntButton   = ref_lookup(?BACK_INT_BUTTON),
  BackSchButton   = ref_lookup(?BACK_SCH_BUTTON),
  ForwardButton   = ref_lookup(?FORWARD_BUTTON),
  BackwardButton  = ref_lookup(?BACKWARD_BUTTON),
  NormalizeButton = ref_lookup(?NORMALIZE_BUTTON),
  %RollButton      = ref_lookup(?ROLL_BUTTON),
  wxButton:disable(ForwIntButton),
  wxButton:disable(ForwSchButton),
  wxButton:disable(BackIntButton),
  wxButton:disable(BackSchButton),
  wxButton:disable(ForwardButton),
  wxButton:disable(BackwardButton),
  wxButton:disable(NormalizeButton).
  %wxButton:disable(RollButton).

refresh() ->
  case utils_gui:is_app_running() of
    false -> ok;
    true ->
      System = ref_lookup(?SYSTEM),
      Options = rev_erlang:eval_opts(System),
      refresh_buttons(Options),
      StateText = ref_lookup(?STATE_TEXT),
      wxTextCtrl:setValue(StateText,utils:pp_system(System))
  end.

start() ->
  InputTextCtrl = ref_lookup(?INPUT_TEXT),
  InputText = wxTextCtrl:getValue(InputTextCtrl),
  FunChoice = ref_lookup(?FUN_CHOICE),
  NumChoice = wxChoice:getSelection(FunChoice),
  StringChoice = wxChoice:getString(FunChoice, NumChoice),
  Fun = utils:stringToFunName(StringChoice),
  Args = utils:stringToCoreArgs(InputText),
  {_, FunArity} = cerl:var_name(Fun),
  case FunArity == length(Args) of
    true ->
      start(Fun, Args),
      ?LOG("start fun " ++ StringChoice ++ " with args " ++ InputText);
    false ->
      utils_gui:update_status_text(?ERROR_NUM_ARGS),
      error
  end.


exec_with(Button) ->
  System = ref_lookup(?SYSTEM),
  PidTextCtrl = ref_lookup(?PID_TEXT),
  PidText = wxTextCtrl:getValue(PidTextCtrl),
  case string:to_integer(PidText) of
    {error, _} ->
      ok;
    {PidInt, _} ->
      PartOption = utils_gui:button_to_option(Button),
      Option = PartOption#opt{id = PidInt},
      NewSystem = rev_erlang:eval_step(System, Option),
      ref_add(?SYSTEM, NewSystem)
  end.

eval_mult(Button) ->
  System = ref_lookup(?SYSTEM),
  StepTextCtrl = ref_lookup(?STEP_TEXT),
  StepText = wxTextCtrl:getValue(StepTextCtrl),
  case string:to_integer(StepText) of
    {error, _} ->
      error;
    {Steps, _} ->
      Option =
        case Button of
          ?FORWARD_BUTTON -> ?MULT_FWD;
          ?BACKWARD_BUTTON -> ?MULT_BWD
        end,
      {NewSystem, StepsDone} = rev_erlang:eval_mult(System, Option, Steps),
      ref_add(?SYSTEM, NewSystem),
      {StepsDone, Steps}
  end.

eval_norm() ->
  System = ref_lookup(?SYSTEM),
  {NewSystem, StepsDone} = rev_erlang:eval_norm(System),
  ref_add(?SYSTEM, NewSystem),
  StepsDone.

eval_roll() ->
  System = ref_lookup(?SYSTEM),
  PidTextCtrl = ref_lookup(?ROLL_PID_TEXT),
  PidText = wxTextCtrl:getValue(PidTextCtrl),
  StepTextCtrl = ref_lookup(?ROLL_STEP_TEXT),
  StepText = wxTextCtrl:getValue(StepTextCtrl),
  {Pid, _} = string:to_integer(PidText),
  {Steps, _} = string:to_integer(StepText),
  case {Pid, Steps} of
    {error, _} -> error;
    {_, error} -> error;
    _ ->
      CorePid = cerl:c_int(Pid),
      {NewSystem, StepsDone, Log} = rev_erlang:eval_roll(System, CorePid, Steps),
      ref_add(?SYSTEM, NewSystem),
      {StepsDone, Steps}
  end.

loop() ->
    receive
        %% ------------------- Button handlers ------------------- %%
        #wx{id = ?START_BUTTON, event = #wxCommand{type = command_button_clicked}} ->
          start(),
          loop();
        #wx{id = ?NORMALIZE_BUTTON, event = #wxCommand{type = command_button_clicked}} ->
          disable_all_buttons(),
          StepsDone = eval_norm(),
          utils_gui:sttext_norm(StepsDone),
          refresh(),
          loop();
        #wx{id = ?ROLL_BUTTON, event = #wxCommand{type = command_button_clicked}} ->
          disable_all_buttons(),
          eval_roll(),
          % utils_gui:sttext_roll,
          refresh(),
          loop();
        #wx{id = RuleButton, event = #wxCommand{type = command_button_clicked}}
          when (RuleButton >= ?FORW_INT_BUTTON) and (RuleButton =< ?BACK_SCH_BUTTON) ->
          disable_all_buttons(),
          exec_with(RuleButton),
          utils_gui:sttext_single(RuleButton),
          refresh(),
          loop();
        #wx{id = RuleButton, event = #wxCommand{type = command_button_clicked}}
          when (RuleButton == ?FORWARD_BUTTON) or (RuleButton == ?BACKWARD_BUTTON) ->
          disable_all_buttons(),
          case eval_mult(RuleButton) of
            error ->
              utils_gui:update_status_text(?ERROR_NUM_STEP);
            {StepsDone, TotalSteps} ->
              utils_gui:sttext_mult(StepsDone, TotalSteps)
          end,
          refresh(),
          loop();
        %% -------------------- Text handlers -------------------- %%
        #wx{id = ?PID_TEXT, event = #wxCommand{type = command_text_updated}} ->
          refresh(),
          loop();
        #wx{id = ?STEP_TEXT, event = #wxCommand{type = command_text_updated}} ->
          refresh(),
          loop();
        #wx{id = _RestIds, event = #wxCommand{type = command_text_updated}} ->
          loop();
        %% -------------------- Menu handlers -------------------- %%
        #wx{id = ?ABOUT, event = #wxCommand{type = command_menu_selected}} ->
          Caption = "About " ++ ?APP_STRING,
          Frame = ref_lookup(?FRAME),
          Dialog = wxMessageDialog:new(Frame, ?INFO_TEXT,
                                       [{style, ?wxOK},
                                        {caption, Caption}]),
          wxDialog:showModal(Dialog),
          wxWindow:destroy(Dialog),
          loop();
        #wx{id = ?OPEN, event = #wxCommand{type = command_menu_selected}} ->
          Frame = ref_lookup(?FRAME),
          openDialog(Frame),
          loop();
        #wx{id = ?ZOOM_IN, event = #wxCommand{type = command_menu_selected}} ->
          zoomIn(),
          loop();
        #wx{id = ?ZOOM_OUT, event = #wxCommand{type = command_menu_selected}} ->
          zoomOut(),
          loop();
        #wx{id = ?EXIT, event = #wxCommand{type = command_menu_selected}} ->
          Frame = ref_lookup(?FRAME),
          wxFrame:destroy(Frame);
        %% ------------------- Other handlers -------------------- %%
        #wx{event = #wxClose{type = close_window}} ->
          Frame = ref_lookup(?FRAME),
          wxFrame:destroy(Frame);
        %% ---------------- Non-supported events ----------------- %%
        Other ->
          io:format("main loop does not implement ~p~n", [Other]),
          loop()
    end.

ref_add(Id, Ref) ->
    ets:insert(?GUI_REF, {Id, Ref}).

ref_lookup(Id) ->
    ets:lookup_element(?GUI_REF, Id, 2).

ref_start() ->
    ?GUI_REF = ets:new(?GUI_REF, [set, public, named_table]),
    ok.

ref_stop() ->
    ets:delete(?GUI_REF).
