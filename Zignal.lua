--!optimize 2
--!strict

export type Signal<T... = ()> = {
	Fire:				(self: Signal<T...>, T...) -> (),
	Wait:				(self: Signal<T...>) -> T...,
	Once:				(self: Signal<T...>, func: (T...) -> ()) -> Connection<T...>,
	Connect:			(self: Signal<T...>, func: (T...) -> ()) -> Connection<T...>,
	DisconnectAll:		(self: Signal<T...>) -> (),
	_next:				Connection<T...> | false,
}

export type Connection<T... = ()> = {
	Connected:			boolean,
	Disconnect:			(self: Connection<T...>) -> (),
	_function: 			(T...) -> (),
	_next: 				Connection<T...> | false,
	_previous: 			Connection<T...> | Signal<T...>,
}

const threads: {thread} = {}

const function Call<T...>(func: (T...) -> (), thread: thread, ...: T...): ()
	func(...)
	table.insert(threads, thread)
end

const function Yield(): ()
	while true do Call(coroutine.yield()) end
end

const Signal, Connection = {}, {}
Signal.__index, Connection.__index = Signal, Connection

const function Disconnect<T...>(self: Connection<T...>): ()
	if self.Connected then self.Connected = false else return end
	const next, previous = self._next, self._previous
	if next then next._previous = previous end
	previous._next = next
end

const function New<T...>(): Signal<T...>
	return setmetatable({_next = false}, Signal) :: Signal<T...>
end

const function Fire<T...>(self: Signal<T...>, ...: T...): ()
	local link = self._next
	while link do
		if link.Connected then
			local length, thread = #threads, nil
			if length == 0 then
				thread = coroutine.create(Yield)
				coroutine.resume(thread)
			else
				thread = threads[length]
				threads[length] = nil
			end
			task.spawn(thread, link._function, thread, ...)
		end
		link = link._next
	end
end

const function Connect<T...>(self: Signal<T...>, func: (T...) -> ()): Connection<T...>
	const next = self._next
	const link = {Connected = true, _previous = self, _function = func, _next = next} :: Connection<T...>
	if next then next._previous = link end
	self._next = link
	return setmetatable(link, Connection)
end

const function Once<T...>(self: Signal<T...>, func: (T...) -> ()): Connection<T...>
	local connection: Connection<T...>
	connection = Connect(self, function(...: T...): ()
		Disconnect(connection)
		func(...)
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
	local link = self._next
	while link do
		link.Connected = false
		link = link._next
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

return table.freeze({new = New})
