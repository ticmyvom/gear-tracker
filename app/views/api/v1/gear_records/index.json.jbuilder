json.set! controller_name, @records, partial: "api/v1/#{controller_name}/#{record_name}", as: record_name.to_sym
