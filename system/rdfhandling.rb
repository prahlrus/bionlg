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
	
	This file specifies several methods and constants for dealing with an RDF graph.
=end

# This program uses the 'rdf' gem
require 'rdf'

module RDFHandling

	FOAF = RDF::Vocabulary.new("http://xmlns.com/foaf/0.1/")
	BIO = RDF::Vocabulary.new("http://purl.org/vocab/bio/0.1/")
	REL = RDF::Vocabulary.new("http://purl.org/vocab/relationship")
	
	# This is a utility method on the array class to see if an array contains a statement
	# equivalent to statement
	
	module StatementMethods
		def has_statement?(statement)
			each do |x|
				if x.subject == statement.subject
					if x.predicate == statement.predicate
						if x.object == statement.object
							return x
						end
					end
				end
			end
			return nil
		end
	end
	
	module Enumerable
		include StatementMethods
	end
	
	include Enumerable
	
	# This is an RDF query that asks for all the foaf:person nodes of the graph,
	# and its solution will contain all of their names.
	
	$queryForPeople = RDF::Query.new do
		pattern [:person, RDF.type, FOAF.Person]
		pattern [:person, FOAF.name, :name]
	end
	
	# These are iterators for enumerating statements about a vertex
	
	def involvedPeople(graph, vertex)
	
		peopleQuery = RDF::Query.new do
			pattern [vertex, :predicate, :object]
			pattern [:object, RDF.type, FOAF.Person]
		end
		
		peopleQuery.execute(graph).each do |match|
			yield RDF::Statement.new(vertex, match[:predicate], match[:object])
		end
		
	end
	
	def listedEvents(graph, vertex)
		
		birthQuery = RDF::Query.new do
			pattern [vertex, BIO.birth, :event]
		end
		deathQuery = RDF::Query.new do
			pattern [vertex, BIO.death, :event]
		end
		eventsQuery = RDF::Query.new do
			pattern [vertex, BIO.event, :event]
		end
		
		
		birthQuery.execute(graph).each do |match|
			yield RDF::Statement.new(vertex, BIO.birth, match[:event])
		end
		deathQuery.execute(graph).each do |match|
			yield RDF::Statement.new(vertex, BIO.death, match[:event])
		end
		eventsQuery.execute(graph).each do |match|
			yield RDF::Statement.new(vertex, BIO.event, match[:event])
		end

	end
	
	def eventToIntervals(graph, vertex)
	
		eventsQuery = RDF::Query.new do
			pattern [:interval, RDF.type, BIO.Interval]
			pattern [:interval, :predicate, vertex]
		end
		
		eventsQuery.execute(graph).each do |match|
			yield RDF::Statement.new(match[:interval], match[:predicate], vertex)
		end
		
	end
	
	def intervalToEvents(graph, vertex)
	
		eventsQuery = RDF::Query.new do
			pattern [vertex, :predicate, :object]
			pattern [:object, RDF.type, BIO.Event]
		end
		
		eventsQuery.execute(graph).each do |match|
			yield RDF::Statement.new(vertex, match[:predicate], match[:object])
		end
		
	end
	
	# This is a predicate that tells whether two vertices are connected by an edge
	
	def verticesConnected?(graph, vertex1, vertex2)
		connectedQuery = RDF::Query.new do
			pattern [vertex1, :predicate, vertex2]
		end
		connectedQuery.execute(graph).each do |match|
			return RDF::Statement.new(vertex1, match[:predicate], vertex2)
		end
		return nil
	end
	
	# These are general predicates for the relevance of a vertex to a person
	
	def personIsDirectlyRelevant?(graph, target, person)
		verticesConnected?(graph, target, person) or verticesConnected?(graph, person, target)
	end
	
	def personIsRelatedByEvent?(graph, target, person)
		connectedQuery = RDF::Query.new do
			pattern [:event, RDF.type, BIO.Event]
			pattern [:event, :predicate1, target]
			pattern [:event, :predicate2, person]
		end
		connectedQuery.execute(graph).each do |match|
			return RDF::Statement.new(match[:event], RDF.type, BIO.event)
		end
		return nil
	end
	
	def personIsRelevant?(graph, target, person)
		personIsDirectlyRelevant?(graph, target, person) or personIsRelatedByEvent?(graph, target, person)
	end
	
	def eventIsRelevant?(graph, target, event)
		verticesConnected?(graph, target, event)
	end
	
	def intervalIsRelevant?(graph, target, interval)
		eventsQuery = RDF::Query.new do
			pattern [interval, :predicate, :object]
			pattern [:object, RDF.type, BIO.Event]
		end
		eventsQuery.execute(graph).each do |match|
			return RDF::Statement.new(vertex, match[:predicate], match[:object]) if eventIsRelevant?(graph, target, match[:object])
		end
		return nil		
	end
	
	# This is a procedure for finding all of the statements in graph whose
	# subject is vertex
	
	def statementsAbout(graph, vertex)
		concerningQuery = RDF::Query.new do
			pattern [vertex, :predicate, :object]
		end
		concerningQuery.execute(graph).each do |s|
			yield RDF::Statement.new(vertex, s[:predicate], s[:object])
		end
	end
	
	# This is an iterator that will yield up all of the FOAF.Person nodes of graph
	# that have a foaf:name matching name
	
	def personsNamed(graph, name)
		isNamedQuery = RDF::Query.new do
			pattern [:person, RDF.type, FOAF.Person]
			pattern [:person, FOAF.name, RDF::Literal.new(name)]
		end
		isNamedQuery.execute(graph).each do |match|
			yield match[:person]
		end
	end

end