module Gimme
  class BlankSlate
    instance_methods.each { |m| undef_method m unless m =~ /^__/ }
  end

  class TestDouble < BlankSlate
    attr_accessor :cls
    attr_accessor :stubbings
    attr_reader :invocations

    def initialize(cls=nil)
      @cls = cls
      @stubbings = {}
      @invocations = {}
    end

    def method_missing(sym, *args, &block)
      sym = MethodResolver.resolve_sent_method(self,sym,args,false)
            
      @invocations[sym] ||= {}        
      @stubbings[sym] ||= {}
      
      @invocations[sym][args] = 1 + (@invocations[sym][args]||0)

      matched_result = nil
      @stubbings[sym].each do |stub_args,result|
        matching = args.size == stub_args.size
        args.each_index do |i| 
          unless args[i] == stub_args[i] || (stub_args[i].respond_to?(:matches?) && stub_args[i].matches?(args[i]))
            matching = false
            break
          end
        end        
        matched_result = result if matching
      end
            
      if matched_result
        matched_result
      elsif sym.to_s[-1,1] == '?'
        false
      else
        nil
      end
    end
  end

  class Gives < BlankSlate
    attr_accessor :raises_no_method_error
    def initialize(double)
      @double = double
      @raises_no_method_error = true
    end

    def method_missing(sym, *args, &block)
      sym = MethodResolver.resolve_sent_method(@double,sym,args,@raises_no_method_error)
      
      @double.stubbings[sym] ||= {}
      @double.stubbings[sym][args] = block.call if block
    end
  end

  class Verifies < BlankSlate
    attr_accessor :raises_no_method_error
    def initialize(double,times=1)
      @double = double
      @times = times
      @raises_no_method_error = true
    end

    def method_missing(sym, *args, &block)
      sym = MethodResolver.resolve_sent_method(@double,sym,args,@raises_no_method_error)
                        
      #gosh, this loop sure looks familiar. just like another ugly loop I know. TODO.
      invoked = 0
      if @double.invocations[sym]
         @double.invocations[sym].each do |invoke_args,count|
           matching = args.size == invoke_args.size
           invoke_args.each_index do |i|
             unless invoke_args[i] == args[i]  || (args[i].respond_to?(:matches?) && args[i].matches?(invoke_args[i]))
               matching = false
               break
             end
           end
           invoked += count if matching
         end
      end
            
      if invoked != @times
        raise VerificationFailedError.new("expected #{sym} to have been called with #{args}")
      end
    end
  end
  
  class MethodResolver
    def self.resolve_sent_method(double,sym,args,raises_no_method_error=true)
      cls = double.cls
      sym = args.shift if sym == :send      
      unless !cls || !raises_no_method_error || cls.instance_methods.include?(sym.to_s)
        raise NoMethodError.new("Your test double of #{cls} may not know how to respond to the '#{sym}' method. 
          If you're confident that a real #{cls} will know how to respond to '#{sym}', then you can
          invoke give! or verify! to suppress this error.")
      end
      sym
    end
  end

  class VerificationFailedError < StandardError
  end
  
  def gimme(cls=nil)
    Gimme::TestDouble.new(cls)
  end

  def give(double)
    Gimme::Gives.new(double)
  end

  def give!(double)
    give = give(double)
    give.raises_no_method_error = false
    give
  end

  def verify(double,times=1)
    Gimme::Verifies.new(double,times)
  end

  def verify!(double,times=1)
    verify = verify(double,times)
    verify.raises_no_method_error = false
    verify
  end
end