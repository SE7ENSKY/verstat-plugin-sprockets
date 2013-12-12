async = require "async"

module.exports = (next) ->
	processDirective = (file, directive, doneDirective) =>
		m = directive.split " "
		if m.length is 2
			command = m[0]
			arg = m[1]
			switch command
				when "require", "require_tree", "include", "include_tree"
					requiredFiles = if command in ["require", "include"]
						@files.findAll
							filename: arg + file.extname
							id: $ne: file.id
						.toJSON()
					else
						@files.findAll
							extname: file.extname
							fullname: $startsWith: arg
							id: $ne: file.id
						.toJSON()

					@depends file, requiredFiles

					result = ""
					for requiredFile in requiredFiles
						result += requiredFile.processed or requiredFile.source
						result += "\n"
					doneDirective null, result
				else
					doneDirective new Error "Unknown directive: #{directive}"
		else doneDirective null, ""

	@postprocessor 'sprockets',
		priority: -100
		postprocess: (file, donePostprocessor) =>
			if file.srcExtname in ['.css', '.js'] and directives = file.source.match new RegExp '/\\*=\\s*.+\\s*\\*/', 'g'
				source = file.source
				async.eachSeries directives, (directiveString, doneDirective) =>
					m = directiveString.match new RegExp '^/\\*=\\s*(.+)\\s*\\*/$'
					processDirective file, m[1].replace(///^\s+///, '').replace(///\s+$///, ''), (err, result) =>
						if err then doneDirective err else
							source = source.replace directiveString, result
							doneDirective()
				, (err) =>
					if err then donePostprocessor err else
						file.source = source
						@modified file
						donePostprocessor()
			else donePostprocessor()
	next()