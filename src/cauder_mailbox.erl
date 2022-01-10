-module(cauder_mailbox).

%% API
-export([uid/0]).
-export([
    new/0,
    add/2,
    remove/2,
    pid_get/2,
    pid_take/2,
    is_element/2,
    take/2,
    uid_take_oldest/2,
    to_list/1
]).

-export_type([mailbox/0, message/0, uid/0]).

-include("cauder.hrl").

-record(mailbox, {
    index = maps:new() :: #{uid() => {cauder_types:proc_id(), cauder_types:proc_id()}},
    map = maps:new() :: #{cauder_types:proc_id() => #{cauder_types:proc_id() => queue:queue(message())}}
}).

-opaque mailbox() :: #mailbox{}.
-opaque uid() :: pos_integer().
-type message() :: #message{}.

%%%=============================================================================
%%% API
%%%=============================================================================

%%------------------------------------------------------------------------------
%% @doc Returns a new and unique message identifier.

-spec uid() -> uid().

uid() -> ets:update_counter(?APP_DB, last_uid, 1, {last_uid, -1}).

%%------------------------------------------------------------------------------
%% @doc Returns a new empty mailbox.

-spec new() -> mailbox().

new() -> #mailbox{}.

%%------------------------------------------------------------------------------
%% @doc Returns a new mailbox formed from `Mailbox1' with `Message' appended to
%% the rear.

-spec add(Message, Mailbox1) -> Mailbox2 when
    Message :: cauder_mailbox:message(),
    Mailbox1 :: cauder_mailbox:mailbox(),
    Mailbox2 :: cauder_mailbox:mailbox().

add(#message{uid = Uid} = Message, #mailbox{index = Index0} = Mailbox) when is_map_key(Uid, Index0) ->
    error({existing_uid, Uid}, [Message, Mailbox]);
add(#message{uid = Uid, src = Src, dst = Dest} = Message, #mailbox{index = Index0, map = DestMap0}) ->
    Index = maps:put(Uid, {Src, Dest}, Index0),

    SrcMap0 = maps:get(Dest, DestMap0, maps:new()),
    Queue0 = maps:get(Src, SrcMap0, queue:new()),

    Queue = queue:in(Message, Queue0),
    SrcMap = maps:put(Src, Queue, SrcMap0),
    DestMap = maps:put(Dest, SrcMap, DestMap0),

    #mailbox{index = Index, map = DestMap}.

%%------------------------------------------------------------------------------
%% @doc Returns `Mailbox1', but with `Message' removed.

-spec remove(Message, Mailbox1) -> Mailbox2 when
    Message :: cauder_mailbox:message(),
    Mailbox1 :: cauder_mailbox:mailbox(),
    Mailbox2 :: cauder_mailbox:mailbox().

remove(#message{uid = Uid, src = Src, dst = Dest} = Message, #mailbox{index = Index0, map = DestMap0}) ->
    Index = maps:remove(Uid, Index0),

    SrcMap0 = maps:get(Dest, DestMap0),
    Queue0 = maps:get(Src, SrcMap0),
    Queue = queue_delete(Message, Queue0),
    SrcMap =
        case queue:is_empty(Queue) of
            true -> maps:remove(Src, SrcMap0);
            false -> maps:put(Src, Queue, SrcMap0)
        end,
    DestMap =
        case maps:size(SrcMap) of
            0 -> maps:remove(Dest, DestMap0);
            _ -> maps:put(Dest, SrcMap, DestMap0)
        end,

    #mailbox{index = Index, map = DestMap}.

%%------------------------------------------------------------------------------
%% @doc Returns the a list of messages queues from `Mailbox' whose destination
%% is the given `Destination'.

-spec pid_get(Destination, Mailbox) -> MessageQueues when
    Destination :: cauder_types:proc_id(),
    Mailbox :: cauder_mailbox:mailbox(),
    MessageQueues :: [queue:queue(message())].

pid_get(Dest, #mailbox{map = DestMap}) when is_map_key(Dest, DestMap) ->
    Queues = maps:fold(
        fun(_, Queue, Acc) ->
            case queue:is_empty(Queue) of
                true -> Acc;
                false -> [Queue | Acc]
            end
        end,
        [],
        maps:get(Dest, DestMap)
    ),
    lists:reverse(Queues);
pid_get(_, _) ->
    [].

%%------------------------------------------------------------------------------
%% @doc Searches the mailbox `Mailbox' for a (random) message whose destination
%% compares equal to `Pid'. Returns `{Message, NewMailbox}' if such a message is found,
%% otherwise `error'. `NewMailbox' is a copy of `Mailbox' where `Message' has
%% been removed.

-spec pid_take(Destination, Mailbox) -> {Message, NewMailbox} | error when
    Destination :: cauder_types:proc_id(),
    Mailbox :: cauder_mailbox:mailbox(),
    Message :: cauder_mailbox:message(),
    NewMailbox :: cauder_mailbox:mailbox().

pid_take(Dest, #mailbox{map = DestMap} = Mailbox) when is_map_key(Dest, DestMap) ->
    SrcMap = maps:get(Dest, DestMap),
    [Queue | _] = maps:values(SrcMap),
    {value, #message{uid = Uid, dst = Dest}} = queue:peek(Queue),
    take(Uid, Mailbox);
pid_take(_, _) ->
    error.

%%------------------------------------------------------------------------------
%% @doc Returns `true' if there is a message in `Mailbox' whose uid compares
%% equal to `Uid', otherwise `false'.

-spec is_element(Uid, Mailbox) -> boolean() when
    Uid :: uid(),
    Mailbox :: cauder_mailbox:mailbox().

is_element(Uid, #mailbox{index = Index}) -> maps:is_key(Uid, Index).

%%------------------------------------------------------------------------------
%% @doc Searches the mailbox `Mailbox' for a message whose uid compares equal to
%% `Uid'. Returns `{value, Message, NewMailbox}' if such a message is found,
%% otherwise `error'. `NewMailbox' is a copy of `Mailbox' where `Message' has
%% been removed.

-spec take(Uid, Mailbox) -> {Message, NewMailbox} | error when
    Uid :: uid(),
    Mailbox :: cauder_mailbox:mailbox(),
    Message :: cauder_mailbox:message(),
    NewMailbox :: cauder_mailbox:mailbox().

take(Uid, #mailbox{index = Index0, map = DestMap0} = Mailbox0) ->
    case maps:find(Uid, Index0) of
        error ->
            error;
        {ok, {Src, Dest}} ->
            Index1 = maps:remove(Uid, Index0),

            SrcMap0 = maps:get(Dest, DestMap0),
            Queue0 = maps:get(Src, SrcMap0),
            {value, Message, List} = list_take(fun(M) -> M#message.uid =:= Uid end, queue:to_list(Queue0)),
            Queue1 = queue:from_list(List),
            SrcMap1 =
                case queue:is_empty(Queue1) of
                    true -> maps:remove(Src, SrcMap0);
                    false -> maps:put(Src, Queue1, SrcMap0)
                end,
            DestMap1 =
                case maps:size(SrcMap1) of
                    0 -> maps:remove(Dest, DestMap0);
                    _ -> maps:put(Dest, SrcMap1, DestMap0)
                end,

            Mailbox1 = Mailbox0#mailbox{index = Index1, map = DestMap1},

            {Message, Mailbox1}
    end.

%%------------------------------------------------------------------------------
%% @doc Returns a complete list of messages, in arbitrary order, contained in
%% `Mailbox'.

-spec to_list(Mailbox) -> [Message] when
    Mailbox :: cauder_mailbox:mailbox(),
    Message :: cauder_mailbox:message().

to_list(#mailbox{map = DestMap}) ->
    maps:fold(
        fun(_, SrcMap, Acc0) ->
            maps:fold(
                fun(_, Queue, Acc1) ->
                    % TODO OPT-24 queue:fold/3
                    lists:append(
                        queue:to_list(Queue),
                        Acc1
                    )
                end,
                Acc0,
                SrcMap
            )
        end,
        [],
        DestMap
    ).

%%%=============================================================================
%%% Utils
%%%=============================================================================

%%------------------------------------------------------------------------------
%% @doc Returns a copy of `Queue1' where the first element matching `Item' is
%% deleted, if there is such an element.

-spec queue_delete(Item, Queue1) -> Queue2 when
    Item :: T,
    Queue1 :: queue:queue(T),
    Queue2 :: queue:queue(T),
    T :: term().

queue_delete(Item, Queue) -> queue:from_list(lists:delete(Item, queue:to_list(Queue))).

%%------------------------------------------------------------------------------
%% @doc Searches the list `List1' for a value such that `Pred(Value)' returns
%% `true', returns `{value, Value, List2}' if such a value is found, otherwise
%% `false'. `List2' is a copy of `List1' where the first occurrence of `Value'
%% has been removed.

-spec list_take(Pred, List1) -> {value, Value, List2} | false when
    Pred :: fun((T) -> boolean()),
    List1 :: [T],
    List2 :: [T],
    Value :: T.

list_take(Pred, L) ->
    list_take(Pred, L, []).

list_take(Pred, [H | T], L) ->
    case Pred(H) of
        true -> {value, H, lists:reverse(L, T)};
        false -> list_take(Pred, T, [H | L])
    end;
list_take(_Pred, [], _L) ->
    false.

%%%%------------------------------------------------------------------------------
%%%% @doc Returns the index of `Item' in `Queue' or `false' if there is no such
%%%% item.
%%
%%-spec queue_index_of(Item, Queue) -> Index | false when
%%    Item :: T,
%%    Queue :: queue:queue(T),
%%    Index :: pos_integer(),
%%    T :: term().
%%
%%queue_index_of(Item, Queue) -> index_of(Item, queue:to_list(Queue)).
%%
%%%%------------------------------------------------------------------------------
%%%% @doc Returns the index of `Item' in `List' or `false' if there is no such
%%%% item.
%%
%%-spec index_of(Item, List) -> Index | false when
%%    Item :: T,
%%    List :: [T],
%%    Index :: pos_integer(),
%%    T :: term().
%%
%%index_of(Item, List) -> index_of(Item, List, 1).
%%
%%index_of(_, [], _) -> false;
%%index_of(Item, [Item | _], Index) -> Index;
%%index_of(Item, [_ | Tail], Index) -> index_of(Item, Tail, Index + 1).
