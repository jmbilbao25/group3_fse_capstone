package com.fse.banking.account.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class KycUploadSlot {
    private String slotName;
    private String blobPath;
    private String uploadUrl;
    private String httpMethod;
}
