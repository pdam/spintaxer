#!/usr/bin/env ruby

class Spintaxer
  
  def spin(s)
    regexp = /\{(.+?)\}/im
    match_data = s.match(regexp)
    return s if match_data.nil?
    first_occurence = match_data[1]
    opening_bracket_index = first_occurence.index("{")
    if opening_bracket_index
      first_occurence = first_occurence[opening_bracket_index+1..-1]
    end
    words = first_occurence.split("|")
    random_word = words[rand(words.size)]
    s.sub!(/\{#{Regexp.escape(first_occurence)}\}/im, random_word)
    return spin(s)
  end

end


f = open("articles/playing.txt" , "r")
contents  = f.read()
f.close()

#'{This|Here} is {some|a {little|wee} bit of} {example|sample} text.'
puts Spintaxer.new.spin(contents)
