module LevenshteinSearcher
	# my iosifovich port was broken, stole this from stackoverflow isntead
	# https://stackoverflow.com/a/46410685
	def self.distance a, b
		a, b = b, a if b.length < a.length

		v0 = (0..b.length).to_a
		v1 = []

		a.each_char.with_index do |a_ch, i|
			v1[0] = i + 1

			b.each_char.with_index do |b_ch, j|
				cost = a_ch == b_ch ? 0 : 1
				v1[j + 1] = [v1[j] + 1, v0[j + 1] + 1, v0[j] + cost].min
			end
			v0 = v1.dup
		end

		return v0[b.length]
	end

	# get the sum of the levenshtein distances from `test` to `strings`
	# if `max` is supplied, the method will exit early and return `nil`
	# if the sum of the distances goes higher.
	# - `test` is a string
	# - `strings` is an array of strings
	def self.sum_distances test, strings, max=nil
		sum = 0
		strings.each do |s|
			sum += distance s, test
			return nil if max && max < sum
		end
		return sum
	end

	# calculate upper bound on sum of levenshtein distance from strings
	def self.calculate_max_distance strings
		return strings.map(&:length).reduce(:+) * strings.length
	end

	# finds all strings with lowest distance
	# - `space` is an array of all possible strings to search through
	# - `strings` is the strings to compare with
	# - `max_dist` (optional) upper bound on distance
	def self.singlethread_search space, strings, max_dist=nil
		max_dist ||= calculate_max_distance strings
		sorted_words = []
		max_dist.times do sorted_words.push [] end

		min_dist = max_dist
		space.each do |word|
			dist = sum_distances word, strings, min_dist
			next if !dist
			sorted_words[dist].push word
			min_dist = dist if dist < min_dist
		end

		return [min_dist, sorted_words]
	end

	# finds all strings with lowest distance, but multithreaded
	# args are the same as on singlethread_search, but with thread count
	def self.multithread_search space, strings, threads, max_dist=nil
		raise ArgumentError, 'Thread count must be more than 1!' if threads <= 1

		max_dist ||= calculate_max_distance strings
		sorted_words = []
		max_dist.times do sorted_words.push [] end

		lists = []
		threads.times do lists.push [] end
		space.length.times do |i|
			lists[i%threads].push space.shift
		end

		threadcount = threads
		min_dist = max_dist
		lists.each.with_index do |list, i|
			Thread.new do
				local_min, local_words = singlethread_search list, strings, max_dist
				min_dist = local_min if local_min < min_dist
				local_words.each.with_index do |w, i|
					sorted_words[i] += w
				end
				threadcount -= 1
			end
		end

		# sorry
		until threadcount == 0
			sleep 1
		end

		return [min_dist, sorted_words]
	end

	# get the alphabet used in the set of strings
	def self.find_alphabet strings
		strings.reduce(:+).chars.uniq.sort
	end

	# generates a search space based on the alphabet and range in `strings`
	# if `file` is specified, then the file will either be written to or
	# read from depending on the `write` argument.
	def self.generate_search_space strings, file: nil, write: true
		if file && !write
			return File.read(file).split "\n"
		end

		alphabet = find_alphabet strings
		range = Range.new *strings.map(&:length).minmax
		counts = alphabet.map do |c|
			occurrences = strings.map do |s| s.count c end
			[c, occurrences.max]
		end.to_h

		space = []
		range.each do |len|
			space += alphabet.repeated_permutation(len).to_a.map &:join
		end

		space.select! do |str|
			counts.all? do |c, v|
				str.count(c) <= v
			end
		end

		if file && write
			File.open file, 'w' do |f|
				space.each do |w|
					f.puts w
				end
			end
		end

		return space
	end

	# perturb the string to have a distance of 1 from the input
	def self.perturb str, alphabet=nil
		alphabet ||= str.chars.uniq.sort
		out = []

		str.each_char.with_index do |c, i|
			# delete one character
			out.push str[0...i] + str[(i+1)..-1]

			alphabet.each do |a|
				# change one character
				temp = str.dup
				temp[i] = a
				out.push temp

				# add one character
				temp = str[0...i] + ' ' + str[i..-1]
				temp[i] = a
				out.push temp
			end
		end

		# add one character to end
		alphabet.each do |a|
			out.push str + a
		end

		return out.uniq - [str]
	end

	# find the strings that have the lowest total levenshtein distance to the
	# strings passed in via a dumb brute force algorithm
	# - `strings` is the list of strings to compare distances with
	# - `space` (optional) is either a string indicating a file path containing
	#   the search space seperated by newlines, or an array of strings
	#   containing the search space.
	# - `write` should only be specified when `space` is a file path.
	#   it indicates whether the file should be written to and the search space
	#   regenerated, or if the file should just be read.
	# - `threads` (optional) is the thread count
	#
	# don't use this, matt's algorithm is faster
	def self.bruteforce_search strings, search_space=nil, write=false, threads: 1
		raise ArgumentError, 'Thread count must be at least 1!' if threads < 1

		space = []
		if search_space.is_a? Array
			raise TypeError, 'Second argument must be a file path!' if write
			space = search_space
		elsif search_space.is_a?(String) || !search_space
			space = generate_search_space strings, file: search_space, write: write
		else
			raise TypeError, 'Search space argument must be a string or array of strings!'
		end

		max_dist = calculate_max_distance strings

		min = words = nil
		if threads == 1
			min, words = singlethread_search space, strings, max_dist
		else
			min, words = multithread_search space, strings, threads, max_dist
		end

		return words[min]
	end

	# search algorithm Matt proposed
	# get all possible perturbations and only keep the ones with lower distances
	def self.matt_search strings, base=nil
		cur = base || strings
		old = []
		alphabet = find_alphabet strings
		cur_dist = cur.map do |x| sum_distances x, strings end .min

		until cur == old || cur == []
			old = cur

			perturbed = cur.map do |w| perturb w, alphabet end .flatten.uniq

			dists = perturbed.map do |x| sum_distances x, strings end
			cur = perturbed.zip(dists)
				.select do |_, d| d <= cur_dist end
				.map(&:first)
				.sort
			cur_dist = dists.min
		end

		return old
	end

	# search algorithm Ashtar proposed
	# start from an empty string and only keep the ones with lower distances
	# similar to Matt's algorithm
	def self.ashtar_search strings
		return matt_search strings, ['']
	end
end
