function Ie_prime_cam = extractIePrimeCamera(S, inFile)

    preferredNames = { ...
        'Ie_prime_cam', ...
        'I_e_prime_cam', ...
        'IePrime_cam', ...
        'Ie_prime_camera', ...
        'Iep_cam', ...
        'Ie_prime'};

    for i = 1:numel(preferredNames)
        name = preferredNames{i};
        if isfield(S, name)
            Ie_prime_cam = S.(name);
            return;
        end
    end

    % If no standard name is found, try to find a single 1024 x 3320 numeric array.
    fns = fieldnames(S);

    candidateNames = {};
    for i = 1:numel(fns)
        value = S.(fns{i});
        if isnumeric(value) && isequal(size(value), [1024, 3320])
            candidateNames{end+1} = fns{i}; %#ok<AGROW>
        end
    end

    if numel(candidateNames) == 1
        warning('Using variable "%s" from %s as Ie_prime_cam.', candidateNames{1}, inFile);
        Ie_prime_cam = S.(candidateNames{1});
        return;
    elseif numel(candidateNames) > 1
        error(['Multiple 1024 x 3320 numeric arrays found in %s. ', ...
               'Please rename the camera-space corrected image to Ie_prime_cam.'], inFile);
    else
        error(['Could not find camera-space IePrime image in %s. ', ...
               'Expected variable name such as Ie_prime_cam.'], inFile);
    end
end