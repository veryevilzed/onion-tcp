defmodule Onion.TCP do
    use Onion.TCP.Server
end

defmodule Onion.TCP.Args do
    @derive [Access]
    defstruct [ 
        ranch: nil, 
        middlewares: {[],[]},
        request: %{ 
            event: :connect,
            status: :connected,
            tag: nil,
            body: nil,
            extra: %{}  
        }, 
        response: %{
            status: :connected, 
            body: "not implemented", 
            extra: %{}
        }, 
        context: %{}, 
        extra: %{}]
end