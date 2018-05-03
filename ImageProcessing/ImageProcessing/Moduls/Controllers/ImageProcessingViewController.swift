//
//  ImageProcessingViewController.swift
//  ImageProcessing
//
//  Created by Artem Orlov on 27/04/2018.
//  Copyright © 2018 ArtemOrlov. All rights reserved.
//

import UIKit
import CoreGraphics


class ImageProcessingViewController: UIViewController {

    @IBOutlet private weak var chooseImageLabel: UILabel!
    @IBOutlet private weak var imageView: UIImageView!
    @IBOutlet private weak var tableView: UITableView!
    @IBOutlet private weak var progressView: UIProgressView!
    @IBOutlet private weak var rotateButton: ProcessingButton!
    @IBOutlet private weak var grayscaleButton: ProcessingButton!
    @IBOutlet private weak var mirrorButton: ProcessingButton!
    @IBOutlet private weak var invertButton: ProcessingButton!
    @IBOutlet private weak var leftMirrorButton: ProcessingButton!

    @IBAction private func processImage(_ sender: ProcessingButton) {
        guard let image = imageView.image else {
            return
        }
        DispatchQueue.global(qos: .userInteractive).async {
            self.viewModel.modifyImage(modification: sender.modification,
                                       image: image)
            { [weak self] index, mode in
                
                guard let index = index else {
                    return
                }
                switch mode {
                case .insert:
                    self?.tableView.insertRows(at: [IndexPath(row: index, section: 0)], with: .fade)
                case .update:
                    self?.tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .fade)
                default:
                    break
                }
            }
        }
    }

    private lazy var processButtons = [rotateButton, grayscaleButton, mirrorButton, invertButton, leftMirrorButton]
    var viewModel = ImageProcessingViewModel()
    var networkService = ImageLoader()

    override func viewDidLoad() {
        super.viewDidLoad()

        let nib = UINib(nibName: ImageProcessingTableViewCell.reuseID,
                        bundle: nil)
        tableView.register(nib,
                           forCellReuseIdentifier: ImageProcessingTableViewCell.reuseID)

        imageView.isUserInteractionEnabled = true
        let gesture = UITapGestureRecognizer(target: self, action: #selector(chooseImage))
        imageView.addGestureRecognizer(gesture)
        setupButtons()
        networkService.imageLoaderDelegate = self
        viewModel.delegate = self
    }

    private func setupButtons() {
        grayscaleButton.modification = .grayscale
        mirrorButton.modification = .mirror
        invertButton.modification = .invert
        leftMirrorButton.modification = .leftSideMirror
        changeButtonsEnableMode(to: false)
    }

    private func openImagePicker(_ source: UIImagePickerControllerSourceType) {
        guard UIImagePickerController.isSourceTypeAvailable(source) else {
            return
        }
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        imagePicker.sourceType = source
        present(imagePicker, animated: true, completion: nil)
    }

    @objc private func chooseImage() {
        presentActionSheet(
            title: Constants.Title.chooseImage,
            message: nil,
            options: .photoLibrary, .camera, .download, .cancel) { [weak self] option in

                switch option {
                case .camera:
                    self?.openImagePicker(.camera)
                case .photoLibrary:
                    self?.openImagePicker(.photoLibrary)
                case .download:
                    self?.showDownloadAlert()
                default:
                    break
                }
        }
    }

    private func showDownloadAlert() {
        let downloadAlert = UIAlertController(title: "Type download link",
                                              message: nil,
                                              preferredStyle: .alert)
        let cancelAction = UIAlertAction(title: Constants.Title.cancel,
                                   style: .cancel)
        let downloadAction = UIAlertAction(title: "Download",
                                           style: .default)
        { _ in
            let string = downloadAlert.textFields?.first?.text
            self.downloadImage(string)
        }
        downloadAlert.addTextField { textField in
            textField.placeholder = "Enter link here"
        }
        downloadAlert.addAction(cancelAction)
        downloadAlert.addAction(downloadAction)
        present(downloadAlert, animated: true)
    }

    private func downloadImage(_ string: String?) {
        guard let string = string,
            let url = URL(string: string) else {
                let alert = UIAlertController(title: "Error",
                                              message: "Wrong url",
                                              preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: Constants.Title.ok,
                                              style: .default))
                present(alert, animated: true)
                return
        }
        progressView.isHidden = false
        chooseImageLabel.isHidden = false
        imageView.image = nil
        changeButtonsEnableMode(to: false)
        networkService.downloadImage(from: url)
    }

    private func savePhotoToLibrary(at indexPath: IndexPath) {
        let image = viewModel.images[indexPath.row].image
        UIImageWriteToSavedPhotosAlbum(image,
                                       self,
                                       #selector(image(_:didFinishSavingWithError:contextInfo:)),
                                       nil)
    }

    @objc private func image(_ image: UIImage, didFinishSavingWithError error: NSError?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            let alert = UIAlertController(title: Constants.Title.saveError,
                                          message: error.localizedDescription,
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: Constants.Title.ok,
                                          style: .default))
            present(alert, animated: true)
        } else {
            let alert = UIAlertController(title: Constants.Title.saved,
                                          message: Constants.Message.imageSaved,
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: Constants.Title.ok,
                                          style: .default))
            present(alert, animated: true)
        }
    }

    private func setNewImage(_ image: UIImage) {
        imageView.image = image
        chooseImageLabel.isHidden = true
        progressView.isHidden = true
        networkService.downloadTask?.cancel()
        changeButtonsEnableMode(to: true)
    }

    private func changeButtonsEnableMode(to isEnable: Bool) {
        processButtons.forEach {
            $0?.isEnabled = isEnable
        }
    }
}

extension ImageProcessingViewController: UIImagePickerControllerDelegate {

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        guard let image = info[UIImagePickerControllerOriginalImage] as? UIImage else {
            return
        }
        setNewImage(image)
        dismiss(animated: true, completion: nil)
    }

}

extension ImageProcessingViewController: UINavigationControllerDelegate {

}

extension ImageProcessingViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.images.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ImageProcessingTableViewCell.reuseID, for: indexPath) as! ImageProcessingTableViewCell
        cell.configure(processedImage: viewModel.images[indexPath.row])
        return cell
    }
}

extension ImageProcessingViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        presentActionSheet(title: nil, message: nil, options: .save, .useAsPrimary, .delete, .cancel) { [weak self] option in
            switch option {
            case .save:
                self?.savePhotoToLibrary(at: indexPath)
            case .delete:
                self?.viewModel.removeObject(at: indexPath)
                tableView.deleteRows(at: [indexPath], with: .fade)
            case .useAsPrimary:
                self?.imageView.image = self?.viewModel.images[indexPath.row].image
            default:
                break
            }
        }
    }
}

extension ImageProcessingViewController: ImageLoaderDelegate {
    func showProgress(_ progress: Float) {
        chooseImageLabel.text = "\(Int(progress * 100))%"
        progressView.progress = progress
    }

    func updateImage(_ image: UIImage) {
        setNewImage(image)
    }
}

extension ImageProcessingViewController: UpdateFilteringCell {

    func updateCell(at index: Int, progress: Float) {
        print(index, progress)
        guard let cell = tableView.cellForRow(at: IndexPath(row: index, section: 0)) as? ImageProcessingTableViewCell else {
            return
        }
        cell.showProgress(progress)
    }


}
