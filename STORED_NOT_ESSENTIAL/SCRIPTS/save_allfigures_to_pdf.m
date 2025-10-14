function [pdfPath, figCount] = save_all_figures_to_pdf(targetDir, pdfFileName)
%   Export all open figures into a single rasterized PDF.
%   [pdfPath, figCount] = save_all_figures_to_pdf(targetDir, pdfFileName)
%   saves all open MATLAB figures to a single PDF named pdfFileName,
%   stored inside targetDir.

    figs = findall(0, 'Type', 'figure');
    figCount = numel(figs);
    pdfPath = '';

    if figCount == 0
        return;
    end

    % Ensure targetDir exists
    if ~exist(targetDir, 'dir')
        mkdir(targetDir);
    end

    % Build full file path
    pdfPath = fullfile(targetDir, pdfFileName);

    % Sort figures by creation order
    [~, sortIdx] = sort([figs.Number]);
    figs = figs(sortIdx);

    % Delete existing PDF if present
    if exist(pdfPath, 'file')
        delete(pdfPath);
    end

    % Export options
    opts = {'ContentType','image','Resolution',300};
    firstPage = true;

    % Loop over figures and append to PDF
    for k = 1:figCount
        fig = figs(k);
        if firstPage
            exportgraphics(fig, pdfPath, opts{:});
            firstPage = false;
        else
            exportgraphics(fig, pdfPath, opts{:}, 'Append', true);
        end
        close(fig);
    end
end