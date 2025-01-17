-record(label_tau, {}).

-record(label_self, {
    var :: cauder_syntax:af_variable()
}).

-record(label_node, {
    var :: cauder_syntax:af_variable()
}).

-record(label_nodes, {
    var :: cauder_syntax:af_variable()
}).

-record(label_start, {
    var :: cauder_syntax:af_variable(),
    name :: atom() | list(),
    host :: 'undefined' | atom()
}).

-record(label_spawn_fun, {
    var :: cauder_syntax:af_variable(),
    node :: 'undefined' | node(),
    function :: cauder_syntax:af_literal()
}).

-record(label_spawn_mfa, {
    var :: cauder_syntax:af_variable(),
    node :: 'undefined' | node(),
    module :: module(),
    function :: atom(),
    args :: [term()]
}).

-record(label_send, {
    dst :: cauder_process:id() | atom(),
    val :: term()
}).

-record(label_receive, {
    var :: cauder_syntax:af_variable(),
    clauses :: cauder_syntax:af_clause_seq()
}).

-record(label_registered, {
    var :: cauder_syntax:af_variable()
}).

-record(label_whereis, {
    var :: cauder_syntax:af_variable(),
    atom :: atom()
}).

-record(label_register, {
    var :: cauder_syntax:af_variable(),
    atom :: atom(),
    pid :: cauder_process:id()
}).

-record(label_unregister, {
    var :: cauder_syntax:af_variable(),
    atom :: atom()
}).

-record(result, {
    env :: cauder_bindings:bindings(),
    expr :: [cauder_syntax:abstract_expr()],
    stack :: cauder_stack:stack(),
    label = #label_tau{} :: cauder_eval:label()
}).
