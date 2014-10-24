defmodule Onion.TCP.Server do
    
    defmacro __using__(_option) do
        quote location: :keep do
            @doc """
            Create server instance 
            args:
                port: 8080 - port
                max_acceptors: uuid - acceptors name
            """
            defmacro deftcpserver name, args \\ [], code do                

                config_name = Dict.get args, :config, :onion 
                config = Application.get_all_env config_name
                port = Dict.get args, :port, Dict.get(config, :port, 5555)
                listener_name = Dict.get args, :listener_name, Dict.get(config, :listener_name, :"tcp_listener_#{U.uuid}")
                max_connections = Dict.get args, :max_connections, Dict.get(config, :max_connection, 100)
                timeout = Dict.get args, :max_connections, Dict.get(config, :timeout, 5000)
                middlewares = Dict.get args, :middlewares, []
                extra = Dict.get args, :extra, []

                quote do
                    defmodule unquote(name) do                      
                        require Logger
                        alias Onion.TCP.Args, as: Args
                        @behaviour :ranch_protocol

                        routes = []


                        def start_link(ref, socket, transport, opts) do
                            pid = spawn_link(__MODULE__, :init, [ref, socket, transport, opts])
                            {:ok, pid}
                        end



                        def init(ref, socket, transport, opts) do
                            :ok = :ranch.accept_ack(ref)
                            args = %Args{ranch: %{socket: socket, transport: transport, opts: opts}, middlewares: {Dict.get(opts, :middlewares, []), []} }
                            
                            args = proto(args)
                            
                            %{response: %{status: status, body: body, extra: extra}} = args
                            case body do
                                nil -> :ok
                                body -> transport.send(socket, body)
                            end

                            case status do
                                :disconnect -> :ok = transport.close(socket)
                                _ -> loop(socket, transport, args)
                            end
                        end



                        def loop(socket, transport, args) do
                            Logger.info "loop TCP"
                            case transport.recv(socket, 0, unquote(timeout)) do
                                {:ok, data} ->
                                    Logger.info "Data recv #{inspect data}"
                                    args |> put_in([:request, :body], data) |> put_in([:request, :event], :data) 
                                    args = proto(args)
                                    %{response: %{status: status, body: body, extra: extra}} = args
                                    case body do
                                        nil -> :ok
                                        body -> transport.send(socket, body)
                                    end

                                    case status do
                                        :disconnect -> :ok = transport.close(socket)
                                        :connected  -> loop(socket, transport, args)
                                    end
                                {:error, :timeout} ->
                                    args |> put_in([:request, :body], nil) |> put_in([:request, :event], :timeout) |> put_in([:request, :status], :disconnect) |> proto
                                    Logger.debug "TCP timeout"
                                    :ok = transport.close(socket)
                                {:error, :closed} ->
                                    args |> put_in([:request, :body], nil) |> put_in([:request, :event], :closed)  |> put_in([:request, :status], :disconnect) |> proto
                                    Logger.debug "TCP closed"
                                    :ok = transport.close(socket)
                                {:error, e} ->
                                    args |> put_in([:request, :body], nil) |> put_in([:request, :event], :error)   |> put_in([:request, :status], :disconnect) |> proto
                                    Logger.debug "TCP error #{inspect e}"
                                    :ok = transport.close(socket)
                                err ->
                                    Logger.error "Data error #{inspect err}"
                                    :ok = transport.close(socket)
                            end
                        end

                        unquote(code)
                        macro_get_compiled_routes(routes)

                        def proto(args), do: args |> put_in([:response, :status], :ok) |> put_in([:response, :body], "protocol not implimented, create deftcpprotocol ...")
                        

                        def start do
                            Logger.metadata([name: unquote(listener_name)])
                            Logger.debug "Trying to TCP Server #{unquote(listener_name)} started at port #{unquote(port)}..."
                            case :ranch.start_listener(unquote(listener_name), unquote(max_connections), :ranch_tcp, [{:port, unquote(5555)}], unquote(name), []) do
                                res = {:ok, _} ->  
                                    Logger.info "TCP Server #{unquote(listener_name)} started at port #{unquote(port)}"
                                    res
                                {_,reason} ->
                                    Logger.info "Failed to start TCP server #{unquote(listener_name)} at port #{unquote(port)}: reason is #{reason}"
                                    receive do after 1000 -> :ok end
                                    :erlang.halt
                            end
                        end

                        defoverridable [proto: 2]
                    end
                end
            end  # defmacro defserver


            defmacro handler module, opts \\ [] do
                quote do
                    routes = [unquote(module) | routes]
                end
            end

            defmacro macro_get_compiled_routes(routes) do
                quote unquote: false do
                    def get_compiled_routes do
                        _routes = Enum.map unquote(Macro.escape routes), fn(route) ->
                            apply(route, :get_routes, [])
                        end
                        _routes |> List.flatten
                    end 
                end
            end


            defmacro deftcpprotocol opts \\ [], code do
                quote do
                    defp proto(state=%Args{}) do
                        unquote(code)
                    end
                end
            end

        end # qoute location: :keep
    end # __using__(_option)

end