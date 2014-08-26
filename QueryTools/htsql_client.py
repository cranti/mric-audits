""" htsql_client

This is an HTSQL client access library.  It's express goal is to assist
casual Python users with parameter escaping, response handling, and
where possible, authentication.  This module is released independent of
the HTSQL distribution under the MIT License and is not considered
"part" of the formal HTSQL distribution or specification.

This module makes many guesses about how to handle authentication
including specific support for HTTP Digest.  Support for OpenID and
HTML+Cookie authentication is done by handling redirects,  looking for
HTML responses, and making guesses about the structure of those forms.

THIS CODE HAS AN UNSTABLE API THAT IS SUBJECT TO CHANGE

"""
import os, re, sys, csv, urllib2, getpass, csv, time, urllib, string, base64
import StringIO
import simplejson
import mimetypes
VERSION = '0.0.2'
csv.field_size_limit(1024*1024)   # default is 128K
__all__ = ['VERSION','htsql_encode','login','latch', 'build_request',
           'HTSQL_Connection','HTSQL_Error', 'Multiplex']
_match_name = re.compile("^[A-Za-z0-9_-]+$").match

class HTSQL_Error(Exception):
    """ HTSQL exception

    This unmarshals the HTSQL error message so that it can be processed
    client side.  Constructor parameters and class attributes include:

        ``uri``         
            offending uri sent as part of the request
    
        ``code``
            HTTP status code -- typically 400 for table or column
            naming issues or 409 for database constraint violation
    
        ``reason``      
            human readable reason for the error
      
        ``detail``
            full error text, including an underlined copy of the
            uri as received/parsed by the HTSQL server

    """
    def __init__(self, uri, code, reason, detail):
        self.uri = uri
        self.code = code
        self.reason = reason
        self.detail = detail

    def as_html(self):
        """ returns exception as a fully-escaped HTML DIV """
        message = self.as_text().replace("&","&amp;")\
                                .replace("<","&lt;")\
                                .replace("\n","<br/>\n")
        return """<div><pre>\n%s\n</pre></div>""" % message

    def __str__(self):
        """ returns exception as plain text 
        
        note: do not use this unescaped result in a HTML response
        or it may enable a cross-site scripting vulnerability
        """
        return """code: %s\nreason: %s\nuri: %s\n\n%s""" % (
                   self.code, self.reason, self.uri, self.detail)

def htsql_encode(value):
    """ encode a value for use within htsql scalar value """
    if type(value) in (list, tuple):
        return "array(%s)" % ",".join([htsql_encode(x) for x in value])
    if value is None:
        return 'null()'
    if value is True:
        return 'true()'
    if value is False:
        return 'false()'
    if type(value) in (int, float):
        return str(value)
    if unicode == type(value):
        strval = value.encode("utf-8")
    elif str == type(value):
        try:
            strval = value.encode("ascii")
        except UnicodeDecodeError:
            print "string isn't 7-bit clean: '%s'" % value
            raise
    else:
        # TODO: convert other cases directly or into strval
        assert False, "unhandled data type, '%s'" % type(value)
    return "'%s'" % urllib.quote(strval.replace("'","''"))

def quote_ident(identifier):
    """ this properly quotes identifiers """
    if str == type(identifier):
        try:
            identifier = identifier.encode("ascii")
        except UnicodeDecodeError:
            print "string isn't 7-bit clean: '%s'" % identifier
            raise
    # TODO: finish me, and integrate into functions below
    return identifier
        
def unroll(pairs):
    if type(pairs) == dict:
        pairs = pairs.items()
    for (k, v) in pairs:
        if type(v) == dict:
            for (a,b) in unroll(v):
                yield ('%s.%s' % (k,a), b)
            continue
        yield (k,v)

def build_request(command, table, locator=None, selector=None,
                  assignment=None, filter=None, perspective=None):
    # TODO: verify table, locator, selector, perspective and
    #       the lhs of assignment and filter when possible
    """ construct htsql request based on various components

    This is a helper function to construct requests based on various
    parts.  Parameters (components of an HTSQL URI) include:

        ``table``       
            the table which the request is applied to; this parameter is
            double-quoted automagically if it does not comply with the
            production; values having a "." or ":" are converted to
            tuples, and items in a tuple are treated as namespaced parts
   
    """
    assert command and "(" in command and ")" in command
    parts = []
    if perspective:
        parts.append("/~%s" % perspective)
    parts.append("/%s" % table)
    if locator:
        if type(locator) in (list, tuple):
            locator = ",".join(selector)
        parts.append("[%s]" % locator)
    if selector:
        if type(selector) in (list, tuple):
            selector = ",".join(selector)
        parts.append("{%s}" % selector)
    parts.append("/%s" % command)
    if filter:
        parts.append("?")
        if type(filter) == dict:
            components = []
            for (k,v) in filter.items():
                if v is None:
                    components.append("is_null(%s)" % k)
                    continue
                components.append("%s=%s" % (k, htsql_encode(v)))
            parts.append("&".join(components))
        elif type(filter) == tuple:
            args = tuple(htsql_encode(v) for v in filter[1:])
            parts.append(filter[0] % args)
        else:
            assert False, "only dict filters permitted currently"
    if assignment:
        if '?' not in parts:
            parts.append("?")
        else:
            parts.append("&")
        parts.append("&".join(["%s:=%s" % (k, htsql_encode(v))
                               for (k,v) in unroll(assignment)]))
    return "".join(parts)

class HTSQL_Connection(object):
    """
    HTSQL Connection superclass
    
    This class encapsulates connectivity to an HTSQL server. It handles
    the establishment of a HTTP connection /w overridable login
    mechanism, submission of URLs, file uploads, parameter substitution,
    and result handling.  Constructor parameters and class attributes:

        ``server``         
            fully-qualified server used as prefix to requests

        ``username``       
            username used for various authentication methods

        ``password``       
            password for authentication, this is prompted
            if needed for server access and not provided
    
    Overridable parameters include:

        ``opener``
            urllib2 opener object used to make requests,
            constructed at initialization via ``build_opener()``

        ``accept``
            accept header value, defaults to ``application/json``
        
        ``perspective``
            a default /~role to be used if one is not provided 
            by the query proper

    """
    def __init__(self, server, username=None,
                 password=None, perspective=None):
        assert server
        self.opener = self.build_opener()
        self.accept = None
        self.server = server
        self.username = username
        self.password = password
        self.perspective = perspective
        # be more forgiving if somebody has a trailing /
        if self.server[-1] == '/':
            self.server = self.server[:-1]

    def build_opener(self):
        """ by default, include cookie processing """
        query_credentials = self.query_credentials
        class BasicAuthHandler(urllib2.BaseHandler):
            def http_request(self, request):
                if request.headers.get('Authorization', None):
                    return request
                (username, password) = query_credentials()
                raw = "%s:%s" % (username, password)
                auth = 'Basic %s' % base64.b64encode(raw).strip()
                request.add_header('Authorization', auth)
                return request
            https_request = http_request
        return urllib2.build_opener(urllib2.HTTPCookieProcessor(),
                                    BasicAuthHandler())

    def query_credentials(self):
        """ obtain username and password from interactive user """
        if not self.username:
            self.username = raw_input("Username? ")
        if not self.password:
            self.password = getpass.getpass("Password? ")
        return (self.username, self.password)
               
    def authenticate(self):
        """ attempt to authenticate with the server

        There are a few cases to a response of /{}

            204 NO CONTENT       we're good to go
            200 OK               assume HTML authentication form
            3xx REDIRECT         assume single sign-on system
            401 AUTHENTICATE     we're asked for basic or digest
        """
        try:
            response = self.opener.open(self.server + "/{}")
        except urllib2.URLError, exce:
            if getattr(exce, 'code', None) == 204:
                # expected result of /{}
                return
            if getattr(exce, 'code', None) == 401:
                # if we get here, it's digest and we didn't handle it,
                # so fall-through and re-raise exception
                auth_header = exce.headers['WWW-Authenticate']
            raise

    def waitfor(self, maxwait=15):
        """ wait for the server to be alive """
        stop = time.time() + maxwait
        while True:
            time.sleep(.1)
            try:
                return self.authenticate()
            except urllib2.URLError, exce:
                if self.is_retryable(exce):
                    # socket error, source port isn't responsive
                    if maxwait  and time.time() < stop:
                        continue
                raise
        assert False, "unreachable"

    def handle_error(self, uri, code, reason, detail):
        """ override if you don't like ``HTSQL_Error`` objects """
        raise HTSQL_Error(uri, code, reason, detail)

    def parse_response(self, response):
        """ based on mimetype, return native python object """
        if not response:
            return None
        mimetype = response.headers.getheader("content-type")
        content_disposition = \
                response.headers.getheader("content-disposition", '')
        if not mimetype:
            return None
        if 'csv' in mimetype:
            return list(csv.reader(response.readlines()))
        if 'json' in mimetype or 'javascript' in mimetype:
            return simplejson.loads(response.read())
        if 'plain' in mimetype \
        or 'x-htsql' in mimetype \
        or 'html' in mimetype \
        or content_disposition.lower().startswith('attachment'):
            return response.read()
        assert False, "unsupported mimetype '%s'" % mimetype

    def is_retryable(self, exce):
        """ some environments have temporary failures, is this one? """
        if exce.args \
        and isinstance(exce.args[0], urllib2.socket.error) \
        and exce.args[0].args and exce.args[0].args[0] in (1, 8, 61):
            return True
        return False

    def execute(self, uri, data=None, headers={}):
        """ perform an HTSQL query against server """
        assert uri.startswith("/")
        for chunk in re.split("%[0-9A-Fa-f][0-9A-Fa-f]", uri):
           assert "%" not in chunk, ("request not uri encoded: " + chunk)
        if self.perspective and not uri.startswith("/~"):
            uri = "/~%s%s" % (self.perspective, uri)
        uri = self.server + urllib.quote(uri)
        printable = "".join(c for c in uri if c in string.printable[:-6])
        assert uri == printable, ("request not printable: " + repr(uri))
        req = urllib2.Request(uri, data, headers)
        req.add_header('Accept', self.accept or 'application/json')
        try:
            result = self.opener.open(req)
            assert result, "no result!"
            return result
        except urllib2.URLError, exce:
            # if it is a temporary failure, retry twice ;(
            if self.is_retryable(exce):
                exce = None
                time.sleep(.25)
                try:
                    return self.opener.open(req)
                except urllib2.URLError, exce:
                    if self.is_retryable(exce):
                        exce = None
                        time.sleep(2.5)
                        try:
                            return self.opener.open(req)
                        except urllib2.URLError, exce:
                            pass
            code = getattr(exce,'code',None)
            if code == 204:
                return None
            reason = getattr(exce,'reason',None)
            detail = None
            if hasattr(exce, 'read'):
                detail = exce.read()
            exce = None # reclaim stack trace
            return self.handle_error(uri, code, reason, detail)

    def __call__(self, uri, *args, **kwargs):
        """ perform an htsql query, args are encoded parameters
       
        This method forms and executes a HTSQL request based on a URI,
        using parameter subsitution using ``args``.  The kwargs have
        special meanings.  

            ``index``        
                indicates the result should be a dictionary indexed by
                the column indicated (by name, not position) -- this 
                only supports the default JSON mimetype

        """
        index = None
        if args:
            args = [htsql_encode(arg) for arg in args]
            uri = uri % tuple(args)
        for (k,v) in kwargs.items():
            if 'index' == k:
                index = v
                continue
            assert False, ("unknown kwarg `%s`" % k)
        response = self.execute(uri)
        result = self.parse_response(response)
        if index is not None:
            mimetype = response.headers.getheader("content-type")
            assert 'json' in mimetype or 'javascript' in mimetype
            retval = {}
            for item in result:
                id = item[index]
                assert id not in retval, ("duplicate id, %s" % id)
                retval[id] = item
            return retval
        return result
    
    def insert(self, table, locator=None, assignment=None, 
               perspective=None, selector=None):
        """ inserts a row into the given table """
        return self.execute(build_request( 'insert()', 
                                table, locator, selector,
                                assignment, None, perspective))

    def update(self, table, locator=None, assignment=None,
               filter=None, perspective=None, selector=None,
               expect=None):
        """ updates rows in a given table (defaults to 1 row) """
        if expect is None:
            expect = 1
        return self.execute(build_request( 'update(expect=%d)' % expect,
                                table, locator, selector,
                                assignment, filter, perspective))

    def merge(self, table, locator=None, assignment=None, 
               filter=None, perspective=None, selector=None):
        """ updates (or inserts if not exists) a row in a given table """
        return self.execute(build_request('merge()', 
                                table, locator, selector,
                                assignment, filter, perspective))

    def delete(self, table, locator=None, filter=None, 
               perspective=None, expect=None):
        """ deletes rows in a given table (defaults to 1 row) """
        if expect is None:
            expect = 1
        return self.execute(build_request( 'delete(expect=%d)' % expect,
                                table, locator, None,
                                None, filter, perspective))

    def select(self, table, locator=None, selector=None,
               filter=None, perspective=None):
        """ selects rows from a given table """
        return self.execute(build_request('select().json()',
                                          table, locator, selector, 
                                          None, filter, perspective))

    def interact(self, table, data, perspective=None, content_type='text/csv'):
        return self.execute(build_request('interact().js',
                                          table, None, None,
                                          None, None, perspective),
                            data, {'Content-Type': content_type})

    def upload(self, table, locator, columns, filenames, perspective=None):
        """
        Simple usage:
        files = { 'iscan'   : "%s/%s_iscan.zip" % (folder,prefix),
                  'playlist': "%s/%s_playlist.zip" % (folder,prefix),
                  'matlab'  : "%s/%s_data.mat" % (folder,prefix) }
        
        fetch.upload('session', '%s.%s' % (ind_id, sessid), files.keys(), files.values())
        
        Note the compound ID in the this example
        """
        # TODO: please include content length in the payload
        # TODO: (wishlist) make this do a streaming post, sendfile?
        assert columns, "columns must be non-empty"
        assert filenames, "filenames must be non-empty"
        assert len(columns) == len(filenames), "columns must match filenames"
        columns = ','.join(["'" + str(c) + "'" for c in columns])
        i = 0
        L = []
        headers = {}
        BOUNDARY = '----------ThIs_Is_tHe_bouNdaRY_$'
        CRLF = '\r\n'
        for fname in filenames:
            L.append('--' + BOUNDARY)
            fdata = open(fname, 'rb').read()
            L.append(
                'Content-Disposition: form-data; name="%s"; filename="%s"'
                     % ('file%i' % i, fname.split(os.sep)[-1]))
            L.append('Content-Type: %s' % self.get_content_type(fname))
            L.append('')
            L.append(fdata)
            i += 1
        L.append('--' + BOUNDARY + '--')
        L.append('')
        post_data = CRLF.join(L)
        content_type = 'multipart/form-data; boundary=%s' % BOUNDARY
        headers['Content-Type'] = content_type
        headers['Content-Length'] = str(len(post_data))
        return self.execute(build_request("dbgui:upload('',%s)" % columns,
                            table, locator, perspective=perspective),
                            post_data, headers)

    def get_content_type(self, filename):
        """ guess mimetype, defaulting to ``application/octet-stream`` """
        return mimetypes.guess_type(filename)[0] \
                or 'application/octet-stream'    

    def cmd_import(self, table, data, charset='utf-8', autocommit=None,
                   mimetype='text/csv', perspective=None):
        """        
        Example:
        table = 'family'
        data = 'action(),id(),notes\ninsert,2006,moredata\ninsert,2007,sirius'
        autocommit = 200 # number of rows to autocommit
        
        cmd_import(table, data, autocommit)
        
        NOTE: * Each row is sepearted by a new line!!
              * data can be a csv file if row[0] is the header
        """
  
        headers = {}
        if charset:
            data = data.encode(charset)
            charset = '; charset = %s' % charset
        headers['Content-Type'] = mimetype + charset
        headers['Content-Length'] = str(len(data))
        return self.execute(build_request('import()', table,
                            perspective=perspective), data, headers)
            

class Multiplex(object):
    """
    This is a connection that is multiplexed over N servers,
    merging the query results into an indexed result set.
    """
    def __init__(self, username=None, password=None, perspective=None):
        self.connections = []
        self.username = username
        self.password = password
        self.perspective = perspective
        if not self.username:
            self.username = raw_input("Username? ")
        if not self.password:
            self.password = getpass.getpass("Password? ")

    def add_server(self, handle, server):
        connection = HTSQL_Connection(server, self.username, 
                             self.password, self.perspective)
        connection.waitfor()
        self.connections.append((handle,connection))

    def query(self, handle, uri, *args, **kwargs):
        for (code, connection) in self.connections:
            if handle == code:
                return connection(uri, *args, **kwargs)
        assert False, ("handle %s not found" % handle)
    
    def __call__(self, uri, *args, **kwargs):
        unified = []
        for (handle, connection) in self.connections:
            result = connection(uri, *args, **kwargs)
            # construct header for CSV output
            if result and type(result[0]) is list:
                if not unified:
                    header = ['server']
                    header.extend(result[0])
                    unified.append(header)
                result = result[1:]
            # add the server to each result
            for row in result:
                if type(row) == dict:
                    assert 'server' not in row
                    row['server'] = handle
                    unified.append(row)
                else:
                    assert type(row) == list
                    chunk = [handle]
                    chunk.extend(row)
                    unified.append(chunk)
        return unified

def login(server, username=None, password=None, perspective=None):
    connect = HTSQL_Connection(server, username, password, perspective)
    connect.waitfor()
    return connect

def latch(main, pidfile, procname=''):
    """ ensure only one copy of a script is running
    
    This helper wraps a ``main`` function implementing an HTSQL script
    with a ``pidfile`` latch so that only one active instance is running
    at any given time.  If stdout notices are helpful, provide a
    ``procname`` with a textual description of the script.
    """
    try:
       data = open(pidfile, "r").read()
       if data :
          os.kill(int(data), 0)
          if procname:
              print "%s is already running" % procname
          return
    except IOError:
       # pid file is missing, good
       pass
    except OSError:
       if procname:
           print "stale pid for %s, running..." % procname
       pass
    f = open(pidfile, "w")
    f.write(str(os.getpid()))
    f.close()
    try:
        # run the application
        main()
    finally:
        os.unlink(pidfile)

