require_relative 'levenshtein_searcher.rb'
# wouldn't really call this a benchmark since it's just one test

lists = [
	%w[watr mizu  wesi su   wodi   awwa],
	%w[er   kuuki ilma hava vozduh aire],
	%w[test hello lorem ipsum]
]
listcount = lists.length

methods = [
	:ashtar_search,
	:matt_search,
	# :bruteforce_search
]

times = {}

methods.each do |m|
	method = LevenshteinSearcher.method m

	t = Time.now
	lists.each do |list|
		method.call list
	end
	times[m] = (Time.now - t) / listcount
end

puts "#{listcount} runs:"
times.each do |m, t|
	puts "#{m.to_s}: #{t}s on avg"
end
