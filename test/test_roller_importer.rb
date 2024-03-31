require "test/unit"
require "active_support/inflector"
require "active_support/core_ext/string/filters"
require "active_support/core_ext/array/conversions"
require "active_support/core_ext/object/duplicable"

config.color_output = false

Importers::Roller.require_deps

class TestRollerImporter < Test::Unit::TestCase
  def setup
    @roller = Importers::Roller
  end

  def test_sluggify
    test_title = "blogs part 1/2"
    assert_equal("blogs-part-1-2", @roller.sluggify(test_title))
  end

  def test_gen_db_query
    test_select = "column"
    test_table = "table"
    test_where = ""
    test_join = ""
    assert_equal(
      "SELECT column FROM table",
      @roller.gen_db_query(test_select, test_table, test_where, test_join)
    )
  end

  test_sluggify
  test_gen_db_query

  should "generate query multiple columns" do
    test_select = ["column1","column2"]
    test_table = "table"
    assert_equal("SELECT column1,column2 FROM table", @roller.gen_db_query(test_select, test_table))
  end

  should "generate query with where clause" do
    test_select = "column"
    test_table = "table"
    test_where = "test = 'text'"
    assert_equal("SELECT column FROM table WHERE test = 'text'", @roller.gen_db_query(test_select, test_table, test_where))
  end

  should "generate query with left join" do
    test_select = ["table1.column","table2.content"]
    test_table = "table1"
    test_join = ["table2 ON table1.condition = table2.test"]
    assert_equal("SELECT table1.column,table2.content FROM table1 LEFT JOIN table2 ON table1.condition = table2.test", @roller.gen_db_query(test_select, test_table, nil, test_join))
  end

  should "generate query with aliases" do
    test_select = ["table.column AS `foo`","table.column2 AS `bar`"]
    test_table = "table AS `table`"
    assert_equal("SELECT table.column AS `foo`,table.column2 AS `bar` FROM table AS `table`", @roller.gen_db_query(test_select, test_table))
  end

  should "generate query with multiple where clauses and joins and aliases" do
    test_select = ["table1.foo AS `foo`","table1.bar AS `bar`","table2.foo AS `foo2`","table3.bar AS `bar2`"]
    test_table = "table1 AS `table1`"
    test_where = ["table1.test1 = 'text1'","table1.test2 = 'text2'"]
    test_join = ["table2 AS `table2` ON table1.condition = table2.test","table3 AS `table3` ON table1.condition = table3.test"]
    assert_equal(
      "SELECT table1.foo AS `foo`,table1.bar AS `bar`,table2.foo AS `foo2`,table3.bar AS `bar2` FROM table1 AS `table1` LEFT JOIN table2 AS `table2` ON table1.condition = table2.test LEFT JOIN table3 AS `table3` ON table1.condition = table3.test WHERE table1.test1
