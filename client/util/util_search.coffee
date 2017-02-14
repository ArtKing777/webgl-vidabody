class SearchUtil

    constructor: () ->
        @reset()

    reset: () ->
        @root = {}

    normalizeKey: (key) ->
        return key.toLowerCase()

    addWithWordsAndSynonyms: (key, value) ->
        @add(key, value)

        re = /[^\w]+/

        subkeys = key.split(re)
        if subkeys.length > 1
            for subkey in subkeys
                @add(subkey, value)

        # if SYNONYMS[key]
        #     for synonym in SYNONYMS[key]
        #         @add(synonym, value)
        #
        #         subkeys = synonym.split(re)
        #         if subkeys.length > 1
        #             for subkey in subkeys
        #                 @add(subkey, value)

    # adds(or replaces) key-value pair
    add: (key, value) ->
        node = @root
        # key must be string
        key = @normalizeKey(key)
        while key.length > 0
            char = key.charAt(0)
            if not node[char]
                node[char] = {
                    # no real need to store full key - debug only
                    #'key': (node.key or '') + char
                }
            node = node[char]
            key = key.substr(1)
        if not node.values
            node.values = []
        # with addWithSynonyms() value duplication == an issue
        if node.values.indexOf(value) < 0
            node.values.push(value)

    # errors: 0 - exact search, >0 - fuzzy search
    find: (key, errors) ->
        results = []

        core = (node, keyReminder, errorCount, results) ->

            if errorCount > errors
                # too fuzzy
                return

            if keyReminder and(keyReminder.length > 0)
                char = keyReminder.charAt(0)
                if node[char]
                    core(node[char], keyReminder.substr(1), errorCount, results)

                # allow extra letter
                core(node, keyReminder.substr(1), errorCount + 1, results)

                for storedKey of node
                    if storedKey.length == 1
                        # allow an error in the letter
                        core(node[storedKey], keyReminder.substr(1), errorCount + 1, results)
                        # allow missing letter
                        core(node[storedKey], keyReminder, errorCount + 1, results)

            else
                if node.values
                    # match
                    for value in node.values
                        if results.indexOf(value) < 0
                            results.push(value)

                for storedKey of node
                    if storedKey.length == 1
                        # collect all remaining values in the branch(so that "bo" matches "boss", "bolivia", etc)
                        core(node[storedKey], '', errorCount, results)

        core(@root, @normalizeKey(key), 0, results)

        return results

    # just some tests
    test: () ->
        @reset()

        words = ['a', 'ab', 'aBc', 'argh', 'bo', 'bolivia', 'boss', 'break', 'bus', 'lol', 'lolz', 'qwerty', 'xyz']
        for w in words
            @add(w, w)
        console.log('SearchUtil tests, words:', words)
        console.log('ab* (ab, aBc) =>', @find('ab', 0))
        console.log('ac, 1 error allowed(a, ab, aBc, argh) =>', @find('ac', 1))
        console.log('bo* (bo, bolivia, boss) =>', @find('bo', 0))
        console.log('bos, 1 error allowed(bo, boss, bolivia, bus) =>', @find('bos', 1))
        console.log('olz, 1 error allowed(lolz) =>', @find('olz', 1))
        console.log('bc, 1 error allowed(aBc, bo, bolivia, boss, break, bus) =>', @find('bc', 1))

        @reset()

        @add('foo', 'foo 1')
        @add('foo', 'foo 2')
        @add('foobar', 'foo 3')
        @add('fubar', 'error')
        @add('ffuuu', 'error')
        console.log('foo(1-3) =>', @find('foo', 1))

        @reset()

search_util = new SearchUtil()
#search_util.test()
