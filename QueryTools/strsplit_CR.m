function [c, matches] = strsplit_CR(str, aDelim, varargin)
%STRSPLIT  Split string at delimiter
%
%NOTE: copied by Carolyn - this is from later version of MATLAB, but I
%wanted to use it on 2012a. Modified a smidge. Should maybe check that
%modifications. Using strjoin_CR (also copied from 2012a)
%**strescape
%
%   C = STRSPLIT(S) splits the string S at whitespace into the cell array
%   of strings C.
%
%   C = STRSPLIT(S, DELIMITER) splits S at DELIMITER into C. DELIMITER can
%   be a string or a cell array of strings. If DELIMITER is a cell array of
%   strings, STRSPLIT splits S along the elements in DELIMITER, in the
%   order in which they appear in the cell array.
%
%   C = STRSPLIT(S, DELIMITER, PARAM1, VALUE1, ... PARAMN, VALUEN) modifies
%   the way in which S is split at DELIMITER.
%   Valid parameters are:
%     'CollapseDelimiters' - If true (default), consecutive delimiters in S
%       are treated as one. If false, consecutive delimiters are treated as
%       separate delimiters, resulting in empty string '' elements between
%       matched delimiters.
%     'DelimiterType' - DelimiterType can have the following values:
%       'Simple' (default) - Except for escape sequences, STRSPLIT treats
%         DELIMITER as a literal string.
%       'RegularExpression' - STRSPLIT treats DELIMITER as a regular
%         expression.
%       In both cases, DELIMITER can include the following escape
%       sequences:
%           \\   Backslash
%           \0   Null
%           \a   Alarm
%           \b   Backspace
%           \f   Form feed
%           \n   New line
%           \r   Carriage return
%           \t   Horizontal tab
%           \v   Vertical tab
%
%   [C, MATCHES] = STRSPLIT(...) also returns the cell array of strings
%   MATCHES containing the DELIMITERs upon which S was split. Note that
%   MATCHES always contains one fewer element than C.
%
%   Examples:
%
%       str = 'The rain in Spain stays mainly in the plain.';
%
%       % Split on all whitespace.
%       strsplit(str)
%       % {'The', 'rain', 'in', 'Spain', 'stays',
%       %  'mainly', 'in', 'the', 'plain.'}
%
%       % Split on 'ain'.
%       strsplit(str, 'ain')
%       % {'The r', ' in Sp', ' stays m', 'ly in the pl', '.'}
%
%       % Split on ' ' and on 'ain' (treating multiple delimiters as one).
%       strsplit(str, {' ', 'ain'})
%       % ('The', 'r', 'in', 'Sp', 'stays',
%       %  'm', 'ly', 'in', 'the', 'pl', '.'}
%
%       % Split on all whitespace and on 'ain', and treat multiple
%       % delimiters separately.
%       strsplit(str, {'\s', 'ain'}, 'CollapseDelimiters', false, ...
%                     'DelimiterType', 'RegularExpression')
%       % {'The', 'r', '', 'in', 'Sp', '', 'stays',
%       %  'm', 'ly', 'in', 'the', 'pl', '.'}
%
%   See also REGEXP, STRFIND, STRJOIN.

%   Copyright 2012 The MathWorks, Inc.
%   $Revision: 1.1.6.2.2.1 $  $Date: 2012/12/17 21:52:14 $

narginchk(1, Inf);

% Initialize default values.
collapseDelimiters = true;
delimiterType = 'Simple';

% Check input arguments.
if nargin < 2
    delimiterType = 'RegularExpression';
    aDelim = '\s';
end
if ~isstr(str)
    error(message('MATLAB:strsplit:InvalidStringType'));
end
if isstr(aDelim)
    aDelim = {aDelim};
elseif ~iscellstr(aDelim)
    error(message('MATLAB:strsplit:InvalidDelimiterType'));
end
if nargin > 2
    funcName = mfilename;
    p = inputParser;
    p.FunctionName = funcName;
    p.addParamValue('CollapseDelimiters', collapseDelimiters);
    p.addParamValue('DelimiterType', delimiterType);
    p.parse(varargin{:});
    collapseDelimiters = verifyScalarLogical(p.Results.CollapseDelimiters, ...
        funcName, 'CollapseDelimiters');
    delimiterType = validatestring(p.Results.DelimiterType, ...
        {'RegularExpression', 'Simple'}, funcName, 'DelimiterType');
end

% Handle DelimiterType.
if strcmp(delimiterType, 'Simple')
    % Handle escape sequences and translate.
   % aDelim = strescape(aDelim);
    aDelim = regexptranslate('escape', aDelim);
else
    % Check delimiter for regexp warnings.
    regexp('', aDelim, 'warnings');
end

% Handle multiple delimiters.
aDelim = strjoin_CR(aDelim, '|');

% Handle CollapseDelimiters.
if collapseDelimiters
    aDelim = ['(?:', aDelim, ')+'];
end

% Split.
[c, matches] = regexp(str, aDelim, 'split', 'match');

end
%--------------------------------------------------------------------------
function tf = verifyScalarLogical(tf, funcName, parameterName)

if isscalar(tf) && isnumeric(tf) && any(tf == [0, 1])
    tf = logical(tf);
else
    validateattributes(tf, {'logical'}, {'scalar'}, funcName, parameterName);
end

end
