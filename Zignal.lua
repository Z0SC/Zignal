--!optimize 2
--!strict

export type Signal<T... = ()> = {
	Fire:				(self: Signal<T...>, T...) -> (),
	Wait:				(self: Signal<T...>) -> T...,
	Once:				(self: Signal<T...>, callback: (T...) -> ()) -> Connection<T...>,
	Connect:			(self: Signal<T...>, callback: (T...) -> ()) -> Connection<T...>,
	DisconnectAll:		(self: Signal<T...>) -> (),
	_next:				Connection<T...> | false,
}

export type Connection<T... = ()> = {
	Connected:			boolean,
	Disconnect:			(self: Connection<T...>) -> (),
	_callback:			(T...) -> (),
	_next:				Connection<T...> | false,
	_previous:			Connection<T...> | Signal<T...>,
}

type Worker<T... = ()> = {Thread: thread, Remaining: Connection<T...> | false, Next: Worker<T...> | false}

local idleWorker: Worker | false = false

const function Dispatch<T...>(worker: Worker<T...>, node: Connection<T...> | false, ...: T...): ()
	while node do
		worker.Remaining = node._next
		if node.Connected then node._callback(...) end
		node = worker.Remaining
	end
	worker.Next = idleWorker
	idleWorker = worker
end

const function Park<T...>(worker: Worker<T...>, node: Connection<T...> | false, ...: T...): ()
	Dispatch(worker, node, ...)
	while true do Dispatch(coroutine.yield()) end
end

const Signal, Connection = {}, {}
Signal.__index, Connection.__index = Signal, Connection

const function Disconnect<T...>(self: Connection<T...>): ()
	if self.Connected then self.Connected = false else return end
	const next, previous = self._next, self._previous
	if next then next._previous = previous end
	previous._next = next
end

const function new<T...>(): Signal<T...>
	return setmetatable({_next = false}, Signal) :: Signal<T...>
end

const function Fire<T...>(self: Signal<T...>, ...: T...): ()
	local node = self._next
	while node do
		const worker = idleWorker or {Thread = coroutine.create(Park), Remaining = false, Next = false}
		idleWorker = worker.Next
		task.spawn(worker.Thread, worker, node, ...)
		node = worker.Remaining
		worker.Remaining = false
	end
end

const function Connect<T...>(self: Signal<T...>, callback: (T...) -> ()): Connection<T...>
	const next = self._next
	const connection = {Connected = true, _previous = self, _callback = callback, _next = next} :: Connection<T...>
	if next then next._previous = connection end
	self._next = connection
	return setmetatable(connection, Connection)
end

const function Once<T...>(self: Signal<T...>, callback: (T...) -> ()): Connection<T...>
	local connection: Connection<T...>
	connection = Connect(self, function(...: T...): ()
		Disconnect(connection)
		callback(...)
	end)
	return connection
end

const function Wait<T...>(self: Signal<T...>): T...
	const thread = coroutine.running()
	local connection: Connection<T...>
	connection = Connect(self, function(...: T...): ()
		Disconnect(connection)
		if coroutine.status(thread) == "suspended" then task.spawn(thread, ...) end
	end)
	return coroutine.yield()
end

const function DisconnectAll<T...>(self: Signal<T...>): ()
	local node = self._next
	while node do
		node.Connected = false
		node = node._next
	end
	self._next = false
end

Signal.Fire = Fire
Signal.Wait = Wait
Signal.Once = Once
Signal.Connect = Connect
Signal.DisconnectAll = DisconnectAll
Connection.Disconnect = Disconnect

table.freeze(Signal)
table.freeze(Connection)

return table.freeze({new = new})
