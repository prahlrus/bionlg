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
	
	This file specifies a module that provides basic data types for the NLG system
=end

#---------------------------------Intermediate Classes------------------------------------

module DataTypes
	# The Relation class: a class for storing tests and RDF predicates for inferring 
	#  new RDF::Statements from given information
	# It is initialized with two procedures, textProc, which takes a graph and two 
	#  vertices of that graph, and returns an output which tells expressProc everything 
	#  it needs to express whether the vertices are in the semantic relation.
	# This class is used in inference, which is currently implemented as a 
	#  dummy method.
	
	class SemanticRelation
		def initialize(symmetric, testProc, expressProc)
			@testProc, @expressProc = testProc, expressProc
			if symmetric
				def test(graph, x, y)
					@expressProc.call(@testProc.call(graph, x, y)) or @expressProc.call(@testProc.call(graph, y, x))
				end
			else
				def test(graph, x, y)
					@expressProc.call(@testProc.call(graph, x, y))
				end
			end
		end
		
	end 
	
	# The DialogueRelation class: a class for storing tests and labels for constructing
	#  instances of the RSNode class from Messages
	# This class is used in content structuring, which is currently implemented as a 
	#  dummy method.
	
	class DiscourseRelation
		def initialize(testProc, label)
			@testProc, @label = testProc, label
			def test(x, y)
				if @testProc.call(x, y)
					return RSNode.new(x, y, label)
				else
					return nil
				end
			end
		end
	end
	
	# The Message class: created by the document planner in an RST and sent to the microplanner
	# Different sorts of messages are implemented as subclasses of Message
	
	class Message
		def initialize(comment)
			@comment, @topic = comment, nil
		end
				
		def topic
			@topic
		end
		
		def set_topic(new_topic)
			@topic = new_topic
		end
		
		def to_s 
			"[#{@comment.inspect}]"
		end
	end
	
	
	# The RSNode class: created by the document planner to structure messages, and sent to the
	#	microplanner. The microplanner also uses RSNodes to structure sentences for the 
	#	surface realizer
	
	class RSNode
	
		def initialize(nucleus, satellite, label)
			@nucleus, @satellite, @label = nucleus, satellite, label
		end
		
		def nucleus
			@nucleus
		end
		
		def satellite
			@satellite
		end
		
		def label
			@label
		end
	
		def to_s
			str = "[#{label} #{nucleus} #{satellite} ]"
		end
	end
	
	# The Sentence class: created by the microplanner to specify text for surface realization
	
	class Sentence
		def initialize(words)
			@words = words
		end
		
		def words
			@words
		end
	end
end