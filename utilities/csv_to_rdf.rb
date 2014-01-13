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

# This program uses the 'rdf' gem
require 'rdf'
require 'rdf/ntriples'

FOAF = RDF::Vocabulary.new("http://xmlns.com/foaf/0.1/")
BIO = RDF::Vocabulary.new("http://purl.org/vocab/bio/0.1/")
REL = RDF::Vocabulary.new("http://purl.org/vocab/relationship/")
DC = RDF::Vocabulary.new("http://purl.org/dc/elements/1.1/")

# Needs a path to the data and schemata files

unless data_path = ARGV[0]
	raise "No path to schemata given!"
end

unless schemata_path = ARGV[1]
	raise "No path to schemata given!"
end

ADDRESSES = RDF::Vocabulary.new("#{schemata_path}addresses")
TEXT_REL = RDF::Vocabulary.new("#{schemata_path}texts")
PERSONS = RDF::Vocabulary.new("#{schemata_path}persons")

# Hashes associating data with RDF predicates

begin
	text_relations = {0 => TEXT_REL.Unknown,
					  1 => TEXT_REL.Author,
					  2 => TEXT_REL.Editor,
					  3 => TEXT_REL.Compiler,
					  4 => TEXT_REL.Publisher,
					  5 => TEXT_REL.Donor,
					  6 => TEXT_REL.Recipient,
					  7 => TEXT_REL.Translator,
					  8 => TEXT_REL.Commentator,
					  9 => TEXT_REL.WorkIncluded}
					  
	addr_relations = {0 => ADDRESSES.Unkown,
					  1 => ADDRESSES.Basic,
					  2 => ADDRESSES.MovedTo,
					  3 => ADDRESSES.FormerAddress,
					  4 => ADDRESSES.LastKnownAddress,
					  5 => ADDRESSES.AncestralAddress,
					  6 => ADDRESSES.ActualResidence,
					  7 => ADDRESSES.HouseHoldRegistrationAddress,
					  8 => ADDRESSES.BirthAddress,
					  9 => ADDRESSES.BurialAddress,
					  10 => ADDRESSES.DeathAddress,
					  11 => ADDRESSES.MigrationRouteBranch,
					  12 => ADDRESSES.Visited,
					  13 => ADDRESSES.EightBannerQingDynasty,
					  14 => ADDRESSES.AlternateBasic}
end

# Classes for reading data out of the csv files

class Entry
	def initialize(filename, extraction_hash)
		datafile = File.open(filename, 'r')
		@Entries = Hash.new()
		datafile.each_line do |l|
			l_data = l.split(',')
			id = l_data[extraction_hash[:id]]
			unless @Entries[id]
				@Entries[id] = Hash.new()
				extraction_hash.keys.each do |k|
					@Entries[id][k] = l_data[extraction_hash[k]].gsub(/\A"|"\Z/, '')
				end
			end
		end
		datafile.close()
	end
	def entries
		@Entries
	end
end

class EntryRelation
	def initialize(filename, entry_hash)
		datafile = File.open(filename, 'r')
		@Relations = Array.new
		@reIndexed = Hash.new
		datafile.each_line do |l|
			l_data = l.split(',')
			this_relation = Hash.new()
			entry_hash.keys.each do |k|
				this_relation[k] = l_data[entry_hash[k]].gsub(/\A"|"\Z/, '')
			end
			@Relations << this_relation
		end
		datafile.close()
	end
	def relations
		@Relations
	end
end

# Intermediary classes for aggregating information

class Person
	def initialize(number, name, gender, birth_date, death_date)
		@this_person = RDF::Node.new('person' + number.to_s)
		@number, @name, @gender = number, name, gender
		birth_date = nil if birth_date == "" or birth_date == "0"
		death_date = nil if death_date == "" or death_date == "0"
		@birth, @death = PersonBirth.new(self, birth_date), PersonDeath.new(self, death_date)
		@sequential, @kin = Array.new(), Array.new()
		@postings = Hash.new()
	end
	def add_status_event(status_event_hash, this_status)
		@sequential << [:status, status_event_hash, this_status]
	end
	def add_addr_event(addr_event_hash, this_addr, kind)
		@sequential << [:addr, addr_event_hash, this_addr, kind]
	end
	def add_posting_to_office(posting_to_office_hash, this_office)
		@sequential << [:posting, posting_to_office_hash, this_office]
	end
	def add_posting_to_addr(posting_id, this_addr)
		@sequential.each do |x|
			if x[1][:posting] == posting_id
				if x[3]
					x[3] << this_addr
				else
					x[3] = [this_addr]
				end
				break
			end
		end
	end
	def add_kinship(this_kinship)
		@kin << this_kinship
	end
	def node
		@this_person
	end
	def number
		@number
	end
	
	# Bring together all the chronological information about the person, create
	# the events for beginning and ending each status, posting, or address relation
	# and prep all that information for output
	
	def generate_sequential!
		@events, @intervals = Array.new, Array.new
		by_date = Hash.new()
		n = number.to_i * 100
		
		@sequential.each do |x|
			h, this_thing = x[1], x[2]
			start_date, end_date = h[:start].to_i, h[:end].to_i
			start_date = nil if start_date == 0
			end_date = nil if end_date == 0
			case x[0]
			when :status
				if start_date
					if by_date[start_date]
						by_date[start_date][0] << PERSONS.StatusStart unless by_date[start_date][0].include?(PERSONS.StatusStart)
						if by_date[start_date][1][PERSONS.status]
							by_date[start_date][1][PERSONS.status] << this_thing
						else
							by_date[start_date][1][PERSONS.status] = [this_thing]
						end
					else
						by_date[start_date] = [[PERSONS.StatusStart], {PERSONS.status => [this_thing], BIO.principal => [self]}]
					end				
				end
				if end_date
					if by_date[end_date]
						by_date[end_date][0] << PERSONS.StatusEnd unless by_date[end_date][0].include?(PERSONS.StatusEnd)
						if by_date[end_date][1][PERSONS.endStatus]
							by_date[end_date][1][PERSONS.endStatus] << this_thing
						else
							by_date[end_date][1][PERSONS.endStatus] = [this_thing]
						end
					else
						by_date[end_date] = [[PERSONS.StatusEnd], {PERSONS.endStatus => [this_thing], BIO.principal => [self]}]
					end
				end
			when :addr
				if start_date
					if by_date[start_date]
						by_date[start_date][0] << x[3] unless by_date[start_date][0].include?(x[3])
						if by_date[start_date][1][ADDRESSES.address]
							by_date[start_date][1][ADDRESSES.address] << this_thing
						else
							by_date[start_date][1][ADDRESSES.address] = [this_thing]
						end
					else
						by_date[start_date] = [[x[3]], {ADDRESSES.address => [this_thing], BIO.principal => [self]}]
					end	
				end
				if end_date
					if by_date[end_date]
						by_date[end_date][0] << ADDRESSES.AddrEnd unless by_date[end_date][0].include?(ADDRESSES.AddrEnd)
						if by_date[end_date][1][ADDRESSES.endAddress]
							by_date[end_date][1][ADDRESSES.endAddress] << this_thing
						else
							by_date[end_date][1][ADDRESSES.endAddress] = [this_thing]
						end
					else
						by_date[end_date] = [[ADDRESSES.AddrEnd], {ADDRESSES.endAddress => [this_thing], BIO.principal => [self]}]
					end	
				end
			when :posting
				if start_date
					if by_date[start_date]
						by_date[start_date][0] << PERSONS.PostingStart unless by_date[start_date][0].include?(PERSONS.PostingStart)
						if by_date[start_date][1][PERSONS.office]
							by_date[start_date][1][PERSONS.office] << this_thing
						else
							by_date[start_date][1][PERSONS.office] = [this_thing]
						end
						if x[3]
							if by_date[start_date][1][PERSONS.postedTo]
								x[3].each do |addr|
									by_date[start_date][1][PERSONS.postedTo] << addr unless by_date[start_date][1][PERSONS.postedTo].contains?(addr)
								end
							else
								by_date[start_date][1][PERSONS.postedTo] = x[3]
							end
						end
					else
						by_date[start_date] = [[PERSONS.PostingStart], {PERSONS.office => [this_thing], BIO.principal => [self]}]
						if x[3]
							by_date[start_date][1][PERSONS.postedTo] = x[3]
						end
					end				
				end
				if end_date
					if by_date[end_date]
						by_date[end_date][0] << PERSONS.PostingEnd unless by_date[end_date][0].include?(PERSONS.PostingEnd)
						if by_date[end_date][1][PERSONS.endOffice]
							by_date[end_date][1][PERSONS.endOffice] << this_thing
						else
							by_date[end_date][1][PERSONS.endOffice] = [this_thing]
						end
					else
						by_date[end_date] = [[PERSONS.PostingEnd], {PERSONS.endOffice => [this_thing], BIO.principal => [self]}]
					end
				end
			end
		end
		
		by_date.each do |date, info|
			rdf_classes, field_hash = info[0], info[1]
			n += 1
			by_date[date] = Event.new(n, date, rdf_classes, field_hash)
		end
		
		@sequential.each do |x|
			h, this_thing = x[1], x[2]
			start_date, end_date = h[:start].to_i, h[:end].to_i
			start_date = nil if start_date == 0
			end_date = nil if end_date == 0
			if start_date
				initiatingEvent = by_date[start_date]
			else
				n += 1
				initiatingEvent = case x[0]
				when :status
					Event.new(n, nil, [PERSONS.StatusStart], {PERSONS.status => [this_thing], BIO.principal => [self]})
				when :addr
					Event.new(n, nil, [x[3]], {ADDRESSES.address => [this_thing], BIO.principal => [self]})
				when :posting
					if x[3]
						Event.new(n, nil, [PERSONS.PostingStart], {PERSONS.office => [this_thing], PERSONS.postedTo => x[3], BIO.principal => [self]})
					else
						Event.new(n, nil, [PERSONS.PostingStart], {PERSONS.office => [this_thing], BIO.principal => [self]})
					end
				end
			end
			
			if end_date
				concludingEvent = by_date[end_date]
			else
				concludingEvent = case x[0]
				when :status
					Event.new(n, nil, [PERSONS.StatusEnd], {PERSONS.endStatus => [this_thing], BIO.principal => [self]})
				when :addr
					Event.new(n, nil, [ADDRESSES.AddrEnd], {ADDRESSES.address => [this_thing], BIO.principal => [self]})
				when :posting
					Event.new(n, nil, [PERSONS.PostingEnd], {PERSONS.office => [this_thing], BIO.principal => [self]})
				end
			end
			
			@events << initiatingEvent unless @events.include?(initiatingEvent)
			@events << concludingEvent unless @events.include?(concludingEvent)
						
			this_interval = case
			when x[0] == :status
				Interval.new(h[:id], initiatingEvent, concludingEvent, 'status', PERSONS.StatusInterval)
			when x[0] == :addr
				Interval.new(h[:id], initiatingEvent, concludingEvent, 'addr', ADDRESSES.AddrInterval)
			when x[0] == :posting
				Interval.new(h[:id], initiatingEvent, concludingEvent, 'posting', PERSONS.PostingInterval)
			end
			
			@intervals << this_interval
		end
		
		by_date.each do |date,event|
			@events << event unless @events.include?(event)
		end
	end
	def to_RDF
		generate_sequential!
		yield RDF::Statement.new(node, RDF.type, FOAF.Person)
		yield RDF::Statement.new(node, FOAF.name, @name)
		if @gender == 1
			yield RDF::Statement.new(node, PERSONS.hasGender, PERSONS.Female)
		else
			yield RDF::Statement.new(node, PERSONS.hasGender, PERSONS.Male)			
		end
		yield RDF::Statement.new(node, BIO.birth, @birth.node)
		yield RDF::Statement.new(node, BIO.death, @death.node)
		@events.each {|e| yield RDF::Statement.new(node, BIO.event, e.node)}
		@birth.to_RDF {|s| yield s}
		@death.to_RDF {|s| yield s}
		@kin.each {|k| yield RDF::Statement.new(node, PERSONS.kin, k.node)}
		@events.each {|x| x.to_RDF {|s| yield s}}
		@intervals.each {|x| x.to_RDF {|s| yield s}}
	end
end

class Text
	def initialize(number, title)
		@this_text = RDF::Node.new('text' + number.to_s)
		@number, @title = number, title
	end
	def node
		@this_text
	end
	def number
		@number
	end
	def to_RDF
		yield RDF::Statement.new(node, RDF.type, TEXT_REL.Text)
		yield RDF::Statement.new(node, TEXT_REL.textTitle, @title)
	end
end
class Office
	def initialize(number, name)
		@this_office = RDF::Node.new('office' + number.to_s)
		@number, @name = number, name
	end
	def node
		@this_office
	end
	def number
		@number
	end
	def to_RDF
		yield RDF::Statement.new(node, RDF.type, PERSONS.Office)
		yield RDF::Statement.new(node, PERSONS.officeName, @name)
	end
end
class PersonBirth
	def initialize(person, date)
		@person, @date = person, date
		@place, @mother, @father = nil, nil, nil
		@this_birth = RDF::Node.new('birthOf' + @person.number)
	end
	def node
		@this_birth
	end
	def setPlace(place)
		@place = place
	end
	def setMother(mother)
		@mother = mother
	end
	def setFather(father)
		@father = father
	end
	def to_RDF
		yield RDF::Statement.new(node, RDF.type, BIO.Birth)
		yield RDF::Statement.new(node, BIO.principal, @person.node)
		yield RDF::Statement.new(node, DC.date, @date) if @date
		yield RDF::Statement.new(node, BIO.place, @place.node) if @place
		yield RDF::Statement.new(node, BIO.parent, @mother.node) if @mother
		yield RDF::Statement.new(node, BIO.parent, @father.node) if @father
	end
end
class PersonDeath
	def initialize(person, date)
		@person, @date = person, date
		@place = nil
		@this_death = RDF::Node.new('deathOf' + @person.number)
	end
	def node
		@this_death
	end
	def setPlace(place)
		@place = place
	end
	def to_RDF
		yield RDF::Statement.new(node, RDF.type, BIO.Death)
		yield RDF::Statement.new(node, BIO.principal, @person.node)
		yield RDF::Statement.new(node, DC.date, @date) if @date
		yield RDF::Statement.new(node, BIO.place, @place.node) if @place
	end
end
class PersonToText
	def initialize(person, title)
		@this_text = RDF::Node.new('text' + number.to_s)
		@number, @title = number, title
	end
	def node
		@this_text
	end
	def number
		@number
	end
	def to_RDF
		yield RDF::Statement.new(node, RDF.type, TEXT_REL.Text)
		yield RDF::Statement.new(node, TEXT_REL.title, @title)
	end
end
class Address
	def initialize(number, name)
		@this_text = RDF::Node.new('addr' + number.to_s)
		@number, @name = number, name
	end
	def node
		@this_text
	end
	def number
		@number
	end
	def to_RDF
		yield RDF::Statement.new(node, RDF.type, ADDRESSES.Address)
		yield RDF::Statement.new(node, ADDRESSES.addressName, @name)
	end
end
class Status
	def initialize(number, name)
		@this_status = RDF::Node.new('status' + number.to_s)
		@number, @name = number, name
	end
	def node
		@this_status
	end
	def number
		@number
	end
	def to_RDF
		yield RDF::Statement.new(node, RDF.type, PERSONS.SocialStatus)
		yield RDF::Statement.new(node, PERSONS.statusName, @name)
	end
end
class Kinship
	def initialize(number, nucleus, relationship, satellite)
		@this_kin_relation = RDF::Node.new('kin_relation' + number.to_s)
		@number, @nucleus, @relationship, @satellite = number, nucleus, relationship, satellite
	end
	def node
		@this_kin_relation
	end
	def number
		@number
	end
	def to_RDF
		yield RDF::Statement.new(node, RDF.type, PERSONS.KinRelation)
		yield RDF::Statement.new(node, PERSONS.nucleus, @nucleus.node)
		yield RDF::Statement.new(node, PERSONS.kinType, @relationship)
		yield RDF::Statement.new(node, PERSONS.satellite, @satellite.node)
	end
end

class Event
	def initialize(number, date, rdf_classes, field_hash)
		@this_event = RDF::Node.new('event' + number.to_s)
		@number, @date, @classes, @field_hash = number, date, rdf_classes, field_hash
	end
	def node
		@this_event
	end
	def number
		@number
	end
	def to_RDF
		@classes.each do |rdf_class|
			yield RDF::Statement.new(node, RDF.type, rdf_class)
		end
		yield RDF::Statement.new(node, DC.date, @date) if @date
		@field_hash.each do |predicate, values|
			values.each do |v|
				yield RDF::Statement.new(node, predicate, v.node)
			end
		end
	end
end
class Interval
	def initialize(number, start_event, end_event, kind, rdf_class)
		@this_event = RDF::Node.new("#{kind}_interval" + number.to_s)
		@number = number
		raise "#{self}: No start!" unless start_event
		raise "#{self}: No end!" unless end_event
		@start_event, @end_event = start_event, end_event
		@type = rdf_class
	end
	def node
		@this_event
	end
	def number
		@number
	end
	def to_RDF
		yield RDF::Statement.new(node, RDF.type, @type)
		if @start_event
			yield RDF::Statement.new(node, BIO.initiatingEvent, @start_event.node) 
			#@start_event.to_RDF {|s| yield s}
		end
		if @end_event
			yield RDF::Statement.new(node, BIO.concludingEvent, @end_event.node) 
			#@end_event.to_RDF {|s| yield s}
		end
	end
end

# Read in the CSV files

people = Entry.new("#{data_path}BIOG_MAIN", {:id => 1, :name => 2, :gender => 5, :born => 8, :died => 12})

texts = Entry.new("#{data_path}TEXT_CODES", {:id => 1, :title => 4})
text_rels = EntryRelation.new("#{data_path}TEXT_DATA", {:text => 1, :person => 2, :type => 3})

addresses = Entry.new("#{data_path}ADDR_CODES", {:id => 0, :name => 1})
addr_rels = EntryRelation.new("#{data_path}BIOG_ADDR_DATA", {:id => 0, :person => 1, :addr => 2, :type => 3, :start => 5, :end => 6})

statuses = Entry.new("#{data_path}STATUS_CODES", {:id => 0, :name => 1})
status_rels = EntryRelation.new("#{data_path}STATUS_DATA", {:id => 0, :person => 1, :status => 3, :start => 4, :end => 8})

offices = Entry.new("#{data_path}OFFICE_CODES", {:id => 1, :name => 2})
postings_to_office = EntryRelation.new("#{data_path}POSTED_TO_OFFICE_DATA", {:id => 0, :person => 1, :office => 2, :start => 4, :end => 8})
postings_to_addr = EntryRelation.new("#{data_path}POSTED_TO_ADDR_DATA", {:id => 0, :posting => 1, :person => 2, :addr => 4})

kinTypes = Entry.new("#{data_path}KINSHIP_CODES", {:id => 0, :type => 5})
kinships = EntryRelation.new("#{data_path}STATUS_DATA", {:id => 0, :nucleus => 1, :satellite => 2, :kintype => 3})

toExpandQueue = Array.new()

people_seen = Hash.new()

texts_seen = Hash.new()
addr_seen = Hash.new()
statuses_seen = Hash.new()
offices_seen = Hash.new()

text_rels.relations.drop(1).each do |r|	
	next unless text_relations[r[:type].strip.to_i]
	unless people_seen[r[:person]]
		next unless people.entries[r[:person]]
		this_person = people.entries[r[:person]]
		people_seen[r[:person]] = Person.new(r[:person], this_person[:name], this_person[:gender], this_person[:born], this_person[:died])
		this_person = people_seen[r[:person]]
		toExpandQueue << this_person
	else
		this_person = people_seen[r[:person]]
	end
	
	unless texts_seen[r[:text]]
		next unless texts.entries[r[:text]]
		this_text = texts.entries[r[:text]]
		texts_seen[r[:text]] = Text.new(r[:text], this_text[:title])
		this_text = texts_seen[r[:text]]
		toExpandQueue << this_text
	else
		this_text = texts_seen[r[:text]]
	end
	toExpandQueue << RDF::Statement.new(this_text.node, text_relations[r[:type].strip.to_i], this_person.node)
end
addr_rels.relations.drop(1).each do |r|	
	next unless addr_relations[r[:type].strip.to_i]
	unless people_seen[r[:person]]
		next unless people.entries[r[:person]]
		this_person = people.entries[r[:person]]
		people_seen[r[:person]] = Person.new(r[:person], this_person[:name], this_person[:gender], this_person[:born], this_person[:died])
		this_person = people_seen[r[:person]]
		toExpandQueue << this_person
	else
		this_person = people_seen[r[:person]]
	end
	
	unless addr_seen[r[:addr]]
		next unless addresses.entries[r[:addr]]
		this_addr = addresses.entries[r[:addr]]
		addr_seen[r[:addr]] = Address.new(r[:addr], this_addr[:name])
		this_addr = addr_seen[r[:addr]]
		toExpandQueue << this_addr
	else
		this_addr = addr_seen[r[:addr]]
	end
	this_person.add_addr_event(r, this_addr, addr_relations[r[:type].strip.to_i])
end
status_rels.relations.drop(1).each do |r|
	unless people_seen[r[:person]]
		next unless people.entries[r[:person]]
		this_person = people.entries[r[:person]]
		people_seen[r[:person]] = Person.new(r[:person], this_person[:name], this_person[:gender], this_person[:born], this_person[:died])
		this_person = people_seen[r[:person]]
		toExpandQueue << this_person
	else
		this_person = people_seen[r[:person]]
	end
	unless statuses_seen[r[:status]]
		next unless statuses.entries[r[:status]]
		this_status = statuses.entries[r[:status]]
		statuses_seen[r[:status]] = Status.new(r[:status], this_status[:name])
		this_status = statuses_seen[r[:status]]
		toExpandQueue << this_status
	else
		this_status = statuses_seen[r[:status]]
	end
	this_person.add_status_event(r, this_status)
end
postings_to_office.relations.drop(1).each do |r|
	unless people_seen[r[:person]]
		next unless people.entries[r[:person]]
		this_person = people.entries[r[:person]]
		people_seen[r[:person]] = Person.new(r[:person], this_person[:name], this_person[:gender], this_person[:born], this_person[:died])
		this_person = people_seen[r[:person]]
		toExpandQueue << this_person
	else
		this_person = people_seen[r[:person]]
	end
	unless offices_seen[r[:office]]
		next unless offices.entries[r[:office]]
		this_office = offices.entries[r[:office]]
		offices_seen[r[:office]] = Office.new(r[:office], this_office[:name])
		this_office = offices_seen[r[:office]]
		toExpandQueue << this_office
	else
		this_office = offices_seen[r[:office]]
	end
	this_person.add_posting_to_office(r, this_office)
end
postings_to_addr.relations.drop(1).each do |r|	
	unless people_seen[r[:person]]
		next unless people.entries[r[:person]]
		this_person = people.entries[r[:person]]
		people_seen[r[:person]] = Person.new(r[:person], this_person[:name], this_person[:gender], this_person[:born], this_person[:died])
		this_person = people_seen[r[:person]]
		toExpandQueue << this_person
	else
		this_person = people_seen[r[:person]]
	end
	
	unless addr_seen[r[:addr]]
		next unless addresses.entries[r[:addr]]
		this_addr = addresses.entries[r[:addr]]
		addr_seen[r[:addr]] = Address.new(r[:addr], this_addr[:name])
		this_addr = addr_seen[r[:addr]]
		toExpandQueue << this_addr
	else
		this_addr = addr_seen[r[:addr]]
	end
	
	this_person.add_posting_to_addr(r[:posting], this_addr)
end

kinships.relations.drop(1).each do |r|
	next unless this_kintype = kinTypes.entries[r[:kintype]]
	unless people_seen[r[:nucleus]]
		next unless people.entries[r[:nucleus]]
		this_nucleus = people.entries[r[:nucleus]]
		people_seen[r[:nucleus]] = Person.new(r[:nucleus], this_nucleus[:name], this_nucleus[:gender], this_nucleus[:born], this_nucleus[:died])
		this_nucleus = people_seen[r[:nucleus]]
		toExpandQueue << this_nucleus
	else
		this_nucleus = people_seen[r[:nucleus]]
	end
	
	unless people_seen[r[:satellite]]
		next unless people.entries[r[:satellite]]
		this_satellite = people.entries[r[:satellite]]
		people_seen[r[:satellite]] = Person.new(r[:satellite], this_satellite[:name], this_satellite[:gender], this_satellite[:born], this_satellite[:died])
		this_satellite = people_seen[r[:satellite]]
		toExpandQueue << this_satellite
	else
		this_satellite = people_seen[r[:satellite]]
	end

	this_kinship = Kinship.new(r[:id], this_nucleus, this_kintype[:type], this_satellite)
	this_nucleus.add_kinship(this_kinship)
	
	toExpandQueue << this_kinship
end

m = 0

graph = RDF::Graph.new

prefix_hash = {:foaf => RDF::URI('http://xmlns.com/foaf/0.1/'),
			   :bio => RDF::URI('http://purl.org/vocab/bio/0.1/'),
			   :rel => RDF::URI('http://purl.org/vocab/relationship/'),
			   :dc => RDF::URI('http://purl.org/dc/elements/1.1/'),
			   :addresses => RDF::URI("#{schemata_path}addresses"),
			   :texts => RDF::URI("#{schemata_path}texts"),
			   :rel => RDF::URI("#{schemata_path}persons")}

output = File.open('my_pipe', 'w')

W = RDF::NTriples::Writer.new(output, {:prefixes => prefix_hash}) do |writer|
	toExpandQueue.each do |x|
		if x.is_a?(RDF::Statement)
			STDERR.puts "Writing: #{m}" if m % 10000 == 0
			writer << x
			m += 1
		else
			x.to_RDF do |s|
				STDERR.puts "Writing: #{m}" if m % 10000 == 0
				writer << s
				m += 1
			end
		end
	end
end

output.close