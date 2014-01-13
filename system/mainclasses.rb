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
require "./inference"
require "./discourse"

include DataTypes
include RDFHandling
include Inference # needed for DocumentPlanner.infer
include Discourse # needed for DocumentPlanner.makeMessages

#--------------------------------Heavy Lifting Classes------------------------------------

module MainClasses
	# The Job class: one for each biography that is to be output.
	# Initializes a document planner, microplanner, and surface realizer, then calls
	#	their methods when it is asked to output.
	
	class Job
		def initialize(knowledge_base, target_name)
			@documentPlanner = DocumentPlanner.new(knowledge_base, target_name)
			@microPlanner = MicroPlanner.new()
			@surfaceRealizer = SurfaceRealizer.new()
			@target_name = target_name
		end
		
		def output()
			n = 1
			@documentPlanner.plan().each do |p|
				STDERR.puts "#{@target_name} Summary Result Number #{n}"
				@surfaceRealizer.realize(@microPlanner.microplan(p))
				n += 1
			end
		end
	end
	
	# The DocumentPlanner class: initialized by a Job
	# Has a plan method, which creates a document plan
	
	class DocumentPlanner
		def initialize(knowledge_base, target_name)
			@knowledgeBase, @targetName = knowledge_base, target_name
		end
		
		# Yields statements from the knowledge_base that are relevant to the vertex
		def selectContent(vertex)
			@target = vertex
			@peopleQueue, @eventsQueue, @intervalsQueue = [vertex], [], []
			@peopleSeen, @eventsSeen, @intervalsSeen = [vertex], [], []
			@statementsSeen = []
			
			def pushPerson(person)
				unless @peopleSeen.include? person
					@peopleSeen.push(person)
					if personIsRelevant?(@knowledgeBase, @target, person)
						return @peopleQueue.push(person)
					end
				end
				return nil
			end
			
			def pushEvent(event)
				unless @eventsSeen.include? event
					@eventsSeen.push(event)
					if eventIsRelevant?(@knowledgeBase, @target, event)
						return @eventsQueue.push(event)
					end
				end
				return nil
			end
			
			def pushInterval(interval)
				unless @intervalsSeen.include? interval
					@intervalsSeen.push(interval)
					if intervalIsRelevant?(@knowledgeBase, @target, interval)
						return @intervalsQueue.push(interval)
					end
				end
				return nil
			end
			
			def pushStatement(s)
				@statementsSeen.push(s) unless @statementsSeen.has_statement?(s)
			end
			
			until @peopleQueue.empty?
				thisPerson = @peopleQueue.shift
				involvedPeople(@knowledgeBase, thisPerson) do |s|
					if pushPerson(s.object)
						pushStatement(s) 
						yield s
					end
				end
				listedEvents(@knowledgeBase, thisPerson) do |s|
					if pushEvent(s.object)
						pushStatement(s) 
						yield s
					end
				end
				statementsAbout(@knowledgeBase, thisPerson) do |s|
					pushStatement(s)
					yield s
				end
				
				until @eventsQueue.empty?			
					thisEvent = @eventsQueue.shift
					involvedPeople(@knowledgeBase, thisEvent) do |s|
						if	pushPerson(s.object)
							pushStatement(s) 
							yield s
						end
					end
					eventToIntervals(@knowledgeBase, thisEvent) do |s|
						if pushInterval(s.subject)
							pushStatement(s) 
							yield s
						end
					end
					statementsAbout(@knowledgeBase, thisEvent) do |s|
						pushStatement(s)
						yield s
					end
					
					until @intervalsQueue.empty?
						thisInterval = @intervalsQueue.shift
						
						intervalToEvents(@knowledgeBase, thisInterval) do |s|
							if pushEvent(s.object)
								pushStatement(s) 
								yield s
							end
						end
						statementsAbout(@knowledgeBase, thisInterval) do |s|
							pushStatement(s)
							yield s
						end
						
					end
				end
			end
			
		end
		
		# Yields a new set of RDF statements about vertex by calling selectContent, and
		# then adding new statements using $relation_array (defined in inference.rb, currently empty)
		def infer(vertex)
			entities = Hash.new()			
			kinds = Hash.new()
			selectContent(vertex) do |s|
				if s.predicate == RDF.type
					if kinds[s.object]
						kinds[s.object].push s.subject unless kinds[s.object].include? s.subject
					else
						kinds[s.object] = [s.subject]						
					end
				end
				if entities[s.subject]
					entities[s.subject].push s unless entities[s.subject].has_statement?(s)
				else
					entities[s.subject] = [s]
				end
			end
			
			subBase = RDF::Graph.new()
			entities.keys.each do |k| 
				entities[k].each do |s|
					subBase.insert(s)
				end
			end
			$relationArray.each do |relation, domain, range|
					kinds[domain].each do |x|
					kinds[range].each do |y|
						if s = relation.test(subBase, x,y)
							subBase.insert(s)
							STDERR.puts s.inspect
						end
					end
				end
			end
			subBase.each_statement do |s|
				yield s
			end
		end
		
		# Yields Message objects from the statements of infer(vertex) using the 
		#  $contentQuerries hash (defined in discourse.rb)
		# Currently implemented as a dummy method - Messages contain a single RDF::Statement
		def makeMessages(vertex)
			infer(vertex) do |s|
				yield Message.new(s)
			end
=begin
			this_graph = RDF::Graph.new
			infer(vertex) do |s|
				this_graph.insert(s)
			end
			$contentQueries.each do |messageClass, query|
				query.execute(this_graph).each do |solution|
					yield messageClass.new(solution)
				end
			end
=end
		end
		
		# Returns a tree of RSNodes whose leaves are the Messages produced by makeMessages
		# Currently a dummy method - tree just has the linear order of the Messages
		def structureContent(vertex)
			parse = Array.new()
			makeMessages(vertex) do |m|
				parse.push m
			end
			first_message = parse.pop
			first_node = RSNode.new(first_message, nil, :text)
			next_node = first_node
			parse.each do |message|
				next_node = RSNode.new(message, next_node, :text)
			end
			return RSNode.new(next_node, nil, :document)
		end
		
		# Calls structureContent on every vertex in the knowledge_base that has the name
		# of the person being summarized, and returns the rhetorical structure trees of
		# each result
		def plan()
			foundPerson = nil
			texts = []
			personsNamed(@knowledgeBase, @targetName) do |vertex|
				foundPerson = vertex
				texts.push structureContent(vertex)
			end
			
			if foundPerson
				STDERR.puts "Planned!" if $verbose_mode
			else
				STDERR.puts "No person of the name '#{@targetName}' was found!"
			end
			return texts
		end
	end
	
	# The MicroPlanner class: initialized by a Job
	# Has a microplan method, which turns a document plan into a text specification
	
	class MicroPlanner
		def initialize()
		end
		
		# Produces sentence-level specifications of a document plan (a rhetorical
		# structure tree)
		# Currently a dummy method - sentence are just the tokens produced by the to_s 
		# method of the RSNodes
		def microplan(docplan)
			sentences = []
			docplan.to_s.each_line do |l|
				sentences << Sentence.new(l.split)
			end
			STDERR.puts "Microplanned!" if $verbose_mode
			return sentences
		end
	end
	
	# The SurfaceRealizer class: initialized by a Job
	# Has a realize method, which turns a text specification into text
	
	class SurfaceRealizer
		def initialize()
		end
		
		# Produces plain text from a sentence-level specification
		# Currently a dummy method - concatenates the tokens from the microplanner
		def realize(textspec)
			STDERR.puts "Realized!" if $verbose_mode
			text = ""
			textspec.each {|s| text += s.words.join(" ") + "\n"}
			return text
		end
	end
	
end