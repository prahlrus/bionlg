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

module Inference

=begin
	Specific semantic relations for inference are not currently implemented in the system
	
	To add a semantic relation, first initialize an instance of the SemanticRelation class,
	then add an entry to the $relationArray that looks like this:
	
		[someRelation, domainType, codomainType]
		
	Where domainType is an RDF class that covers the domain of the relation, and codomainType
	is an RDF class that covers the codomain, or range, of the relation.
=end
	
	$relationArray = []
end