=begin
This program requires Ruby 1.9 or higher.

#!/Users/will/.rvm/rubies/ruby-1.9.2-p180/bin/ruby
=end

# encoding: utf-8

=begin
	Authors: William Prahl, John David Stone
	December 2012
	
	This is a natural language generation system for creating biographical summaries.
	See the enclosed README file for license and usage information.
	
	This program is part of a pipeline for producing files containing RDF triples.
	It is given a file prefix as a command line argument and reads in RDF tripels from 
	standard input, splitting them into separate files by their subjects.
=end

predicates, relevance = Hash.new([]), Hash.new([])
header = Array.new()
names = Array.new()

raise 'No prefix given!' unless file_prefix = ARGV[0]

# Read in the data, organized by the subject of each RDF statement
# Create the subdirectories to divide the output as needed

n, m = 0, 1
dir_no = 0
STDIN.each_line do |l|
	STDERR.puts "Reading:#{n}" if n % 10000 == 0	
	if l.split.first == "@prefix"
		header << l
	else
		list = l.split
		subject = list.shift
		comment = list.join(' ')
		predicate = list.shift
		object = list.join(' ').gsub(/\./,'').strip
		unless predicates[subject].empty?
			this_content = [predicate, object].join(' ')
			predicates[subject] << this_content unless predicates[subject].include? this_content
			relevance[subject] << object
		else
			predicates[subject] = [[predicate, object].join(' ')]
			relevance[subject] = [object]
		end
		if predicate == "foaf:name"
			this_name = object.strip.gsub(/["\.]/,'').strip
			names << [this_name, subject, dir_no]
			if m % 500 == 0 # 500 files per subdirectory
				`mkdir "#{file_prefix}#{dir_no}"` 
				dir_no += 1
			end
			m += 1
		end
	end
	n += 1
end

STDERR.puts "Done!"

`mkdir "#{file_prefix}#{dir_no}"` 

# The header is the prefix definitions that will preface every file

header_file = File.new("#{file_prefix}rdf_header", 'w')
header.each {|l| header_file.puts l}
header_file.close

# Create the registry of named entities and their files' locations

name_file = File.new("#{file_prefix}names", 'w')
names.each {|name, subject, dir_no| name_file.puts "#{name}\t#{dir_no}/#{subject}"}
name_file.close

STDERR.puts "#{predicates.keys.length} subjects found"
STDERR.puts "#{names.length} named subjects found"

# Compute second-order relevance information

n = 0
new_relevance = Hash.new()
names.each do |name, subject, dir_no|
	STDERR.puts "Processing relevance for subject:#{n}" if n % 10 == 0
	new_relevance[subject] = Array.new()
	relevance[subject].each do |x|
		next if x == subject
		if relevance[x]
			new_relevance[subject] << x unless new_relevance[subject].include? x
			relevance[x].each do |y|
				next if y == subject
				new_relevance[subject] << y if relevance[y] and not new_relevance[subject].include? y
			end
		end
	end
	n += 1
end

STDERR.puts "Done!"

# Add indirect references to named entities

n = 0
relevance.each do |subject, objects|
	unless new_relevance[subject]
		objects.each do |o|
			if this_queue = new_relevance[o]
				STDERR.puts "Adding indirect references \##{n}" if n % 1000 == 0
				this_queue << subject unless this_queue.include? subject
			end
		end
	end
	n += 1
end

STDERR.puts "Done!"

# Write output

n = 0
names.each do |name, subject, dir_no|
	this_file = File.new("#{file_prefix}#{dir_no}/#{subject}", 'w')
	predicates[subject].each do |c|
		STDERR.puts "Writing output:#{n}" if n % 10000 == 0
		this_file.puts [subject, c].join(" ") + " ."
		n += 1
	end
	new_relevance[subject].each do |ent|
		predicates[ent].each do |c|
		STDERR.puts "Writing output:#{n}" if n % 10000 == 0
		this_file.puts [ent, c].join(" ") + " ."
		n += 1
	end
	end
	this_file.close
end