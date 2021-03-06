class IdConfirmJob < ApplicationJob
  queue_as :default

  def perform(contract_id)
    @client = Aws::Rekognition::Client.new({
    region: Rails.application.credentials.dig(:aws, :region),
    credentials: Aws::Credentials.new(
      Rails.application.credentials.dig(:aws, :access_key_id),
      Rails.application.credentials.dig(:aws, :secret_access_key))
    })

    @contract = Contract.find(contract_id)
    @user = @contract.user
    @document = @user.user_document
    id_confirm(@document)
  end

  private 

  def id_confirm(document_image)
    attrs = {
      image: {
        s3_object: {
          bucket: Rails.application.credentials[Rails.env.to_sym][:aws][:bucket],
          name: document_image
        },
      },
      max_label: 20,
      mun_confidence: 90.0
    }
    response_image = @cliente.detect_labels attrs
    response_image.labels.each do |labels|
      if (labels.name == "Document" || labels.name == "License" || labels.name == "Driving License" || labels.name == "Id Cards")
        is_document = true
        what_document?()
      else
        is_document = false
      end
      perform_next_job(is_document)
    end
  end

  def what_document? ()    
    attrs = {
      image: {
        s3_object: {
          bucket: Rails.application.credentials[Rails.env.to_sym][:aws][:bucket],
          name: document_image
        },
      },
    }
    response_text = @client.detect_text  attrs
    response_text = text_detection.each do |text|
      if (text.detect_text == "CPF" && text.detect_text == "NOME" || text.detect_text == "FILIACAO")
        if (text.detect_text == "PERMISSAO" || text.detect_text == "HAB")
          id_type = "CNH"
        else
          id_type = "RG"
        end
      end
    end
  end

  def perform_next_job(valid)
    if valid == true
      IdCheckJob.perform_later contract.id
    else
      @contract.status = "error, not a valid document"
    end
  end

end
