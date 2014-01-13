=begin
This program requires Ruby 1.9 or higher.

#!/Users/will/.rvm/rubies/ruby-1.9.2-p180/bin/ruby
=end

# encoding: utf-8

=begin
	Authors: William Prahl, John David Stone
	December 2012
	
	This is a program to retrieve RDF information that has been stored in multiple
	directories, using a registry of names. It should be invoked on the command line
	with a path to the base directory containing the registry of names and the
	locations of their associated files
=end

raise 'No prefix given!' unless file_prefix = ARGV[0]

names = Hash.new()
name_file = File.new("#{file_prefix}names", 'r')
name_file.each_line do |l|
	this_name, person = l.split("\t")
	if names[this_name]
		names[this_name] << person
	else
		names[this_name] = [person]
	end
end

STDERR.puts "A list of people in the database follows:"
names.each do |name, people|
	STDERR.puts "#{name}: #{people.length} entry(s)"
end

subjects = Array.new()

STDIN.each_line do |l|
	l.strip!
	if l != ""
		unless names[l]
			STDERR.puts "Warning: '#{l}' not found in the database" 
		else
			names[l].each {|x| subjects << x.strip}
		end
	else
		break
	end
end

unless subjects.empty?
	header_file = File.new("#{file_prefix}rdf_header", 'r')
	header_file.each_line {|l| STDOUT.puts l}
	until subjects.empty?
		this_subject = subjects.shift
		subject_file = File.new("#{file_prefix}#{this_subject}", 'r')
		subject_file.each_line {|l| STDOUT.puts l}
		subject_file.close
	end
end