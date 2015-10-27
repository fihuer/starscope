module Starscope::Lang
  module Puppet
    VERSION = 1

    require 'puppet/parser/lexer'

    @lexer = nil

    def self.match_file(name)
      name.end_with?('.pp')
    end

    def self.extract(path, contents)
      @lexer ||= ::Puppet::Parser::Lexer.new
      @lexer.file = path

      reset_state

      @lexer.scan do |name, token|
        @lexer.indefine = false
        # p "#{name} #{token}"
        case name
        when :CLASS
          @class = token
        when :DEFINE
          @define = token
        when :CLASSREF # Might be a override or a reference (require/notify)
          @override = token
        when :NAME
          if @class
            yield :defs, token[:value], :line_no => token[:line], :type => :class
            reset_state
          elsif @define
            yield :defs, token[:value], :line_no => token[:line], :type => :type
            reset_state
          elsif token[:value] == 'include'
            @include = true
          elsif @include
            yield :imports, token[:value], :line_no => token[:line]
            reset_state
          elsif @inherits
            yield :calls, token[:value], :line_no => token[:line]
            reset_state
          elsif @resource && !@in_args # It's a resource without a variable in his name
            yield add_resource(@resource[:value], token[:value], token[:line])
          elsif !@in_if_statement
            @sym = token # Could be a resource or a function call
          end
        when :STRING
          if @class
            yield :defs, token[:value], :line_no => token[:line], :type => :class
            reset_state
          elsif @override
            if @override[:value] == "Class" # That's class override/reference
              yield :defs, token[:value], :line_no => token[:line], :type => :class
            else
              yield add_resource(@override[:value], token[:value], token[:line])
            end
            reset_state
          elsif @resource && !@in_args # It's a ressource without a variable in his name
            yield add_resource(@resource[:value], token[:value], token[:line])
          end
        when :DQPRE
          @dq = token[:value]
        when :VARIABLE
          if @dq
            var_name = token[:value]
            @dq += "${#{var_name}}"
          end
          yield :reads, token[:value], :line_no => token[:line]
        when :DQMID
          @dq && @dq += token[:value]
        when :DQPOST # DQuoted string finished
          if @dq
            @dq += token[:value]
            if @resource && !@in_args # It's a ressource with a variable in his name
              yield add_resource(@resource[:value], @dq, token[:line])
            end
          end
        when :INHERITS
          @inherits = true
        when :IF, :ELSIF, :ELSE
          @in_if_statement = true
        when :COLON
          @in_args = true
        when :SEMIC
          @in_args && @in_args = false
        when :LBRACE
          if @in_if_statement
            reset_state
          elsif @sym
            @resource = @sym
            @sym = nil
          end
        when :LPARENT
          if @sym
            @function = @sym
            @sym = nil
          end
        when :RBRACE
          @resource && @resource = nil
          @in_args && reset_state
        when :RPARENT
          if @function
            reset_state
          end
        else
          @sym = nil
        end
      end
    end

    def self.add_resource(klass, name, line)
      klass = klass.capitalize
      resource = "#{klass}[#{name}]"
      return :defs, resource, :line_no => line, :type => :resource
    end

    def self.reset_state
      @class = nil
      @define = nil
      @sym = nil
      @func = nil
      @type = nil
      @var = nil
      @include = nil
      @dq = nil
      @in_if_statement = false
      @inherits = false
      @override = nil
      @in_args = false
    end
  end
end
