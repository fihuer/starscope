module Starscope::Lang
  module ERB
    VERSION = 1

    ERB_START = /<%(?:-|={1,4})?/
    ERB_END = /-?%>/

    def self.match_file(name)
      name.end_with?('.erb')
    end

    def self.extract(path, contents, &block)
      multiline = false # true when parsing a multiline <% ... %> block

      contents.lines.each_with_index do |line, line_no|
        line_no += 1 # zero-index to one-index

        if multiline
          term = line.index(ERB_END)
          if term
            yield FRAGMENT, :Ruby, frag: line[0...term], line_no: line_no
            line = line[term + 1..-1]
            multiline = false
          else
            yield FRAGMENT, :Ruby, frag: line, line_no: line_no
          end
        end

        next if multiline

        line.scan(/#{ERB_START}(.*?)#{ERB_END}/) do |match|
          yield FRAGMENT, :Ruby, frag: match[0], line_no: line_no
        end

        line.gsub!(/<%.*?%>/, '')

        match = /#{ERB_START}(.*)$/.match(line)
        next unless match

        yield FRAGMENT, :Ruby, frag: match[1], line_no: line_no
        multiline = true
      end
    end
  end
end
