# levenshtein searcher

finds strings with the least levenshtein distance from a given set of strings

## example usage

```rb
require_relative 'levenshtein_searcher.rb'

LevenshteinSearcher.ashtar_search     ["test", "lorem", "ipsum", "hello"]
LevenshteinSearcher.matt_search       ["test", "lorem", "ipsum", "hello"]
LevenshteinSearcher.bruteforce_search ["test", "lorem", "ipsum", "hello"] # note: much much slower

# all should return ["hesem", "heslm", "hesm", "hestm", "hesum", "iesem", "ieslm", "iesm", "iestm", "iesum", "lesem", "leslm", "lesm", "lestm", "lesum", "oesm", "resm", "tesem", "teslm", "tesm", "testm", "tesum"]
```

## credits

all [name]`_search` methods were proposed by them
