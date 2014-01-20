$:.unshift(File.dirname(__FILE__))
require 'lipid_classifier'
Dir.glob(File.join(File.dirname(File.absolute_path(__FILE__)),"rules", "*.rb")).map {|rfile| require rfile }

NumberNames = {1 =>  "single", 2 =>  "double", 3 =>  "triple", 4 =>  "quadruple"}
class LipidClassifier
  class Rules    
    # Helpers
    def self.lambda_smart_match_bool(searches, match_count = 1)
      lambda do |molecule| 
        searches.map {|search| molecule.matches(search, uniq: true).size > (match_count - 1)}
      end
    end
    def self.lambda_smart_match_bool_by_count(searches, match_count = 1)
      lambda do |molecule| 
        searches.map {|search| molecule.matches(search, uniq: true).size == match_count}
      end
    end
    def self.lambda_smart_match_count(searches)
      lambda do |molecule| 
        searches.map {|search| molecule.matches(search, uniq: true).size } 
      end
    end
    def self.method_add_to_hash_from_smarts_and_count(hash, smart_key, number, lookup_hash = Smarts)
      new_key = [NumberNames[number], smart_key.to_s].join("_").to_sym
      hash[new_key] = lambda_smart_match_bool_by_count(lookup_hash[smart_key], number)
    end
    # BOOLEAN responses, or numbers
    TestBlock = {:test => lambda {|molecule| molecule.each_match("c1ccccc1", uniq: true).to_a.size > 0}, #BENZENE 
    }
    TestHash = {:ester => ["[#6][CX3](=O)[OX2H0][#6]"]}
    (1..4).to_a.map {|i| method_add_to_hash_from_smarts_and_count(TestBlock, :ester, i, TestHash) }
    def self.analyze(molecule)
      # returns a hash, so no association is lost.  
      analysis = {}
      rule = Smarts.map.first  
      Smarts.map do |rule|
        begin 
          analysis[rule.first] = rule.last.call(molecule)
        rescue ArgumentError => e
          File.open('smarts_errors.log', 'a') {|i| i.puts "Rule contains an invalid smarts string:\n\t#{rule.first}\n\t\t#{e}" }
        end
      end
      p analysis
      analysis
    end
    def self.analyze_set(molecules)
      #returns an array of hashes
    end
    def write_analysis_to_file(array, file = "testing.csv")
      File.open(file, "w") do |outputter|
        outputter.puts nil
      end
    end
    def self.create_set_of_rules_from_smart(smart_key, rule_set = Smarts)
      # returns a hash of generated rules
      hsh = {}
      hsh[smart_key] = lambda_smart_match_bool(rule_set[smart_key])
      (1..4).to_a.map {|i| method_add_to_hash_from_smarts_and_count(hsh, smart_key, i, rule_set) }
      hsh[[smart_key.to_s,"count"].join("_").to_sym] = lambda_smart_match_count(rule_set[smart_key])
      hsh
    end

    # ON LOADING 
    # Install the base rules
    FunctionalGroups.each do |k,v|
      Smarts.merge! create_set_of_rules_from_smart(k, FunctionalGroups)
    end
    AminoAcids.each do |k,v|
      Smarts.merge! create_set_of_rules_from_smart(k, AminoAcids)
    end
  end
end

#LipidClassifier::Rules.prep_rules
# Generate rules for all the SMARTS


if $0 == __FILE__
  mol = Rubabel["LMFA01010001", :lmid]
  classifier = LipidClassifier::Rules
  classifier.analyze mol
  abort
  puts "Should be true: #{LipidClassifier::Rules::TestBlock[:test].call Rubabel["C1=CC=CC=C1"]}"
  puts "ARE YOU SURE? You'll have to comment out the code to run these..."
  #File.open("amino_acids.yml", "w") {|f| f.write YAML.dump LipidClassifier::Rules::AminoAcids}
  #File.open("smart_search_strings.yml", "w") {|f| f.write YAML.dump LipidClassifier::Rules::SmartSearchStrings}
end
