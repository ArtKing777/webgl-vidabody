get_used_hashes = (root_hash, callback) ->

	count = 0

	used_hashes = []

	if (typeof window != 'undefined') and not confirm('Are you prepared to waste a lot of bandwidth?')
		return

	get_hash = (hash, callback) ->
		count += 1

		if typeof request == 'undefined'
			_request = require('../old-controllers/requests').request
			if FILE_SERVER_DOWNLOAD_API?
				_api = FILE_SERVER_DOWNLOAD_API
			else
				_api = eval("require('../api_config').FILE_SERVER_DOWNLOAD_API")
		else
			_request = request

		_request('GET', _api + hash, callback, (xhr) ->
			console.error('Error ' + xhr.status + ' when requesting ' + hash + ': ' + xhr.response.substr(0, 9) + '...')
		)

	process_hash = (s) ->
		count -= 1

		if s.charAt(0) != '{'
			# not a json, most probably - do not parse
			console.log('File content does not look like JSON: ' + s.substr(0, 9) + '...')
		else
			m = undefined
			r = /[a-z0-9]{40,64}/g
			while m = r.exec(s)
				used_hashes.push(m[0])
				get_hash(m[0], process_hash)

		if count == 0
			callback(used_hashes)

	get_hash(root_hash, process_hash)

exports.get_used_hashes = get_used_hashes