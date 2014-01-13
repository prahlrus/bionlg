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
	
	This program should be invoked on the command line with a path to the base directory
	containing the registry of names and the locations of their associated files.
=end

require 'optparse' # handles command line arguments

require "./datatypes" 
require "./mainclasses"
require "./rdfhandling" 

include DataTypes
include MainClasses
include RDFHandling

# This program uses the 'rdf' gem.
require "rdf/n3"

#------------------------Command Line Arguments----------------------------

options = Hash.new

optparse = OptionParser.new do |opts|
	opts.banner = "Usage: bio_nlg.rb [options] <PATH OF BASE DIRECTORY OF KNOWLEDGE BASE>\nBy default, all of these options are false."
	
	opts.on('-h', '--help', 'Display this information.') do
		puts opts
		exit
	end
	
	options[:verbose] = false
	opts.on('-v', '--verbose', 'Write progress to STDERR.') do
		options[:verbose] = true
	end

end

optparse.parse!
raise 'No prefix given!' unless file_prefix = ARGV[0]

begin
	$verbose_mode = options[:verbose]
end

#------------------------------Main Program--------------------------------

# Look for all of the named entities in the database

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

# Display all of them and wait for user input

STDERR.puts "A list of people in the database follows:"
names.each do |name, people|
	STDERR.puts "#{name}: #{people.length} entry(s)"
end

subjects = Array.new()
subject_names = Array.new()

STDIN.each_line do |l|
	l.strip!
	if l != ""
		unless names[l]
			STDERR.puts "Warning: '#{l}' not found in the database" 
		else
			names[l].each {|x| subjects << x.strip}
			subject_names << l.strip
		end
	else
		break
	end
end

# Get the data on the specified individuals

STDERR.puts "Retreiving information on: #{subject_names.join(', ')}."

outfile = File.open('temp_data.nt', 'w')

unless subjects.empty?
	header_file = File.new("#{file_prefix}rdf_header", 'r')
	header_file.each_line do |l| 
		outfile.puts l
	end
	until subjects.empty?
		this_subject = subjects.shift
		subject_file = File.new("#{file_prefix}#{this_subject}", 'r')
		subject_file.each_line do |l|
			l = l.strip
			outfile.puts l 
		end
		subject_file.close
	end
end

outfile.close()

FOAF = RDF::Vocabulary.new("http://xmlns.com/foaf/0.1/")

knowledgeBase = RDF::Graph.load('temp_data.nt')

STDERR.puts "Creating Jobs"

# Do the NLG for each specified individual

$queryForPeople.execute(knowledgeBase).each do |solution|
	currentJob = Job.new(knowledgeBase, solution[:name])
	STDOUT.puts currentJob.output()
end