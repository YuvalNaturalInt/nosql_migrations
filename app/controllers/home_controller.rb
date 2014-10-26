class HomeController < ApplicationController

  skip_before_action :verify_authenticity_token

  def index

  end

  def start_migration
    connection_details = params[:connection_details]
    connection_details_file = Tempfile.new('connection_details')
    connection_details_file << connection_details
    connection_details_file.close

    @configuration = Mongify::Configuration.parse(connection_details_file.path)
    @translation = Mongify::Translation.load(@configuration.sql_connection)

    @is_databases_valid = check_sql_connection && check_nosql_connection

    @translation_string = @translation.print
    
    puts @translation_string

    tables_with_one_reference = []

    all_tables = {}

    @translation.tables.each do |table|
      all_tables[table.name] = table
      number_of_referece_columns = 0
      table.columns.each do |column|
        number_of_referece_columns += 1 if column.references
      end
      tables_with_one_reference << table if number_of_referece_columns == 1
    end

    tables_with_one_reference.each do |table|
      table.columns.each do |column|
        if(column.references)
          referenced_table_name = column.references
          table.options['embed_in'] = referenced_table_name
        end
      end
    end
    
    begin
      @translation.process(@configuration.sql_connection, @configuration.no_sql_connection)
    rescue Exception => exception
      puts exception.backtrace
    end

  end

  def check_sql_connection
    @configuration.sql_connection.valid? && @configuration.sql_connection.has_connection?
  end

  # Checks no sql connection if it's valid and has_connection?
  def check_nosql_connection
    @configuration.no_sql_connection.valid? && @configuration.no_sql_connection.has_connection?
  end
end