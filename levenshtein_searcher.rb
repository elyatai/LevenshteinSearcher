module LevenshteinSearcher
	# ported from https://bitbucket.org/clearer/iosifovich/
	def self.distance a, b
		a = a.chars
		b = b.chars
		start = LevenshteinSearcher.mismatch a, b
		return 0 if !start

		a = a[start..-1]; b = b[start..-1]
		a, b = b, a if a.length > b.length

		buffer = (0..b.length).to_a
		buffer_size = buffer.size - 1

		1.upto a.length do |i|
			temp = buffer[0]
			buffer[0] += 1
			1.upto buffer_size do |j|
				prev = buffer[j-1]
				cur = buffer[j]
				temp = [
					[cur, prev].min + 1,
					temp + (a[i-1] == b[j-1] ? 0 : 1)
				].min
				temp, buffer[j] = buffer[j], temp
			end
		end

		return buffer.last
	end

	# ported from c++s std::mismatch
	def self.mismatch *arrs
		first = arrs.shift
		first.zip(*(arrs.map &:to_a)).each_with_index do |x, i|
			return i if x.uniq.size > 1
		end
		return nil
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
		max_dist ||= self.calculate_max_distance strings
		sorted_words = []
		max_dist.times do sorted_words.push [] end

		min_dist = max_dist
		space.each do |word|
			dist = 0
			strings.each do |w|
				dist += self.distance w, word
				next if min_dist < dist
			end
			sorted_words[dist].push word
			min_dist = dist if dist < min_dist
		end

		return [min_dist, sorted_words]
	end

	# finds all strings with lowest distance, but multithreaded
	# args are the same as on singlethread_search, but with thread count
	def self.multithread_search space, strings, threads, max_dist=nil
		raise 'Thread count must be more than 1!' if threads <= 1

		max_dist ||= self.calculate_max_distance strings
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
				local_min, local_words = self.singlethread_search list, strings, max_dist
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

	# generates a search space based on the alphabet and range in `strings`
	# if `file` is specified, then the file will either be written to or
	# read from depending on the `write` argument.
	def self.generate_search_space strings, file: nil, write: true
		if file && !write
			return File.read(file).split "\n"
		end

		chars = strings.reduce(:+).chars.uniq.sort
		range = Range.new *strings.map(&:length).minmax

		space = []
		range.each do |len|
			space += chars.repeated_permutation(len).to_a.map &:join
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

	# find the strings that have the lowest total levenshtein distance to the
	# strings passed in
	# - `strings` is the list of strings to compare distances with
	# - `space` is either a string indicating a file path containing the search
	#   space seperated by newlines, or an array of strings containing the full
	#   search space.
	# - `write` should only be specified when `space` is a file path.
	#   it indicates whether the file should be written to and the search space
	#   regenerated, or if the file should just be read.
	# - `threads` (optional) is the thread count
	def self.search strings, search_space=nil, write=false, threads: 1
		raise ArgumentError, 'Thread count must be at least 1!' if threads < 1

		space = []
		if search_space.is_a? Array
			raise TypeError, 'Second argument must be a file path!' if write
			space = search_space
		elsif search_space.is_a? String || !search_space
			space = self.generate_search_space strings, file: search_space, write: write
		else
			raise TypeError, 'Search space argument must be a string or array of strings!'
		end

		max_dist = self.calculate_max_distance strings

		min = words = nil
		if threads == 1
			min, words = self.singlethread_search space, strings, max_dist
		else
			min, words = self.multithread_search space, strings, threads, max_dist
		end

		return [min, words.select(&:any?).map(&:sort)]
	end
end

if __FILE__ == $0
	puts LevenshteinSearcher.search(
		%w[watr mizu wesi wodi awwa su], # %w[er kuuki ilma hava vozduh aire],
		'levenshtein.txt',
		ARGV.empty?,
		threads: 20
	)[1][0].join ', '
end
