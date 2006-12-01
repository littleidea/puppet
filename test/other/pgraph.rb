#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2006-11-16.
#  Copyright (c) 2006. All rights reserved.

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppettest'
require 'puppettest/graph'

class TestPGraph < Test::Unit::TestCase
	include PuppetTest
	include PuppetTest::Graph
	
	Edge = Puppet::Relationship
	
	def test_matching_edges
	    graph = Puppet::PGraph.new
	    
	    event = Puppet::Event.new(:source => "a", :event => :yay)
	    none = Puppet::Event.new(:source => "a", :event => :NONE)
	    
	    edges = {}
	    
	    edges["a/b"] = Edge["a", "b", {:event => :yay, :callback => :refresh}]
	    edges["a/c"] = Edge["a", "c", {:event => :yay, :callback => :refresh}]
	    
	    graph.add_edge!(edges["a/b"])
	    
	    # Try it for the trivial case of one target and a matching event
	    assert_equal([edges["a/b"]], graph.matching_edges([event]))
	    
	    # Make sure we get nothing with a different event
	    assert_equal([], graph.matching_edges([none]))
	    
	    # Set up multiple targets and make sure we get them all back
	    graph.add_edge!(edges["a/c"])
	    assert_equal([edges["a/b"], edges["a/c"]].sort, graph.matching_edges([event]).sort)
	    assert_equal([], graph.matching_edges([none]))
    end
    
    def test_dependencies
        graph = Puppet::PGraph.new
        
        graph.add_edge!("a", "b")
        graph.add_edge!("a", "c")
        graph.add_edge!("b", "d")
        
        assert_equal(%w{b c d}.sort, graph.dependencies("a").sort)
        assert_equal(%w{d}.sort, graph.dependencies("b").sort)
        assert_equal([].sort, graph.dependencies("c").sort)
    end
    
    # Test that we can take a containment graph and rearrange it by dependencies
    def test_splice
        one, two, middle, top = build_tree
        contgraph = top.to_graph
        
        # Now add a couple of child files, so that we can test whether all containers
        # get spliced, rather than just components.
        
        # Now make a dependency graph
        deps = Puppet::PGraph.new
        
        contgraph.vertices.each do |v|
            deps.add_vertex(v)
        end
        
        {one => two, "f" => "c", "h" => middle}.each do |source, target|
            deps.add_edge!(source, target, :callback => :refresh)
        end
        
        deps.to_jpg("deps-before")
        
        deps.splice!(contgraph, Container)
        
        assert(! deps.cyclic?, "Created a cyclic graph")
        
        # Now make sure the containers got spliced correctly.
        contgraph.leaves(middle).each do |leaf|
            assert(deps.edge?("h", leaf), "no edge for h => %s" % leaf)
        end
        one.each do |oobj|
            two.each do |tobj|
                assert(deps.edge?(oobj, tobj), "no %s => %s edge" % [oobj, tobj])
            end
        end
        
        nons = deps.vertices.find_all { |v| ! v.is_a?(String) }
        assert(nons.empty?,
            "still contain non-strings %s" % nons.inspect)
        
        deps.to_jpg("deps-after")
        
        deps.edges.each do |edge|
            assert_equal({:callback => :refresh}, edge.label,
                "Label was not copied on splice")
        end
    end
end

# $Id$