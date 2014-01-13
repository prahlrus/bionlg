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
	For this program to work correctly, the string "ABSOLUTE_PATH" in the code below
	will need to be replaced by an absolute file path to the directory containing the
	user-defined schemata "addresses.nt" "persons.nt" and "texts.nt"
=end

STDOUT.puts "@prefix rdf:	<http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix rdfs:	<http://www.w3.org/2000/01/rdf-schema#> .
@prefix owl:	<http://www.w3.org/2002/07/owl#> .
@prefix foaf:	<http://xmlns.com/foaf/0.1/> .
@prefix bio:	<http://purl.org/vocab/bio/0.1/> .
@prefix rel:	<http://purl.org/vocab/relationship/> .
@prefix dc:	<http://purl.org/dc/elements/1.1/> .
@prefix addresses:	<ABSOLUTE_PATH/schemata/addresses> .
@prefix persons:	<ABSOLUTE_PATH/schemata/persons> .
@prefix texts:	<ABSOLUTE_PATH/schemata/texts> ."

rdf_regex = /http:\/\/www.w3.org\/1999\/02\/22-rdf-syntax-ns#/
rdfs_regex = /http:\/\/www.w3.org\/2000\/01\/rdf-schema#/
owl_regex = /http:\/\/www.w3.org\/2002\/07\/owl#/
foaf_regex = /http:\/\/xmlns.com\/foaf\/0.1\//
bio_regex = /http:\/\/purl.org\/vocab\/bio\/0.1\//
rel_regex = /http:\/\/purl.org\/vocab\/relationship\//
dc_regex = /http:\/\/purl.org\/dc\/elements\/1.1\//
addresses_regex = /ABSOLUTE_PATH\/schemata\/addresses/
persons_regex = /ABSOLUTE_PATH\/schemata\/persons/
texts_regex = /ABSOLUTE_PATH\/schemata\/texts/
junk_regex = /\^\^http:\/\/www.w3.org\/2001\/XMLSchema#integer/

prefixes = {rdf_regex => "rdf:",
			rdfs_regex => "rdfs:",
			owl_regex => "owl:",
			foaf_regex => "foaf:",
			bio_regex => "bio:",
			rel_regex => "rel:",
			dc_regex => "dc:",
			addresses_regex => "addresses:",
			persons_regex => "persons:",
			texts_regex => "texts:"}

n = 0
STDIN.each_line do |l|
	STDERR.puts n if n % 10000 == 0
	prefixes.each do |regex, prefix|
		l = l.gsub(regex, prefix)
	end
	l = l.gsub(/[<>]/,"")
	l = l.gsub(junk_regex,"")
	STDOUT.puts l
	n += 1
end