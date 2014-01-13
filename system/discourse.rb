=begin
This program requires Ruby 1.9 or higher.

#!/Users/will/.rvm/rubies/ruby-1.9.2-p180/bin/ruby
=end

# encoding: utf-8

=begin
	Authors: William Prahl, John David Stone
	December 2012
	
	This is part of a natural language generation system for creating biographical summaries.
	See the enclosed README file for license and usage information.
=end

require "./datatypes" 
require "./rdfhandling"

include DataTypes
include RDFHandling

module Discourse

	# These relative paths should work now, but consider using an absolut path if they do not
	PERSONS = RDF::Vocabulary.new("../schemata/persons.nt")
	ADDRS = RDF::Vocabulary.new("../schemata/addresses.nt")
	TEXTS = RDF::Vocabulary.new("../schemata/texts.nt")

	class KinMessage < Message
	end
	
	class HappeningMessage < Message
	end
	
	class BirthMessage < HappeningMessage
	end
	
	class DeathMessage < HappeningMessage
	end
		
	class StatusMessage < HappeningMessage
	end
	
	class PostingMessage < HappeningMessage
	end

	class AddrMessage < HappeningMessage
	end
	
	class TextMessage < Message
	end
	
	# Currently, only kinQuery and textQuery are implemented. They look through the graph
	#  to see if any statements about kinship relations can be made.
	kinQuery = RDF::Query.new do
		pattern [:subject, PERSONS.kin, :kinship]
		pattern [:kinship, RDF.type, PERSONS.KinRelation]
		pattern [:kinship, PERSONS.nucleus, :subject]
		pattern [:kinship, PERSONS.sattelite, :object]
		pattern [:kinship, PERSONS.kinType, :kintype]
	end
	textQuery = RDF::Query.new do
		pattern [:subject, RDF.type, FOAF.Person]
		pattern [:text, RDF.type, TEXTS.Text]
		pattern [:text, :textrelation, :subject]
	end
	
=begin
	birthQuery
	deathQuery
	statusQuery
	postingQuery
	addrQuery
	textQuery
=end
	
	$contentQueries = {KinMessage => kinQuery,
					   TextMessage => textQuery}
	
=begin
						BirthMessage => birthQuery,
						DeathMessage => deathQuery,
						StatusMessage => statusQuery,
						PostingMessage => postingQuery,
						AddrMessage => addrQuery,
						TextMessage => textQuery
=end
						
end