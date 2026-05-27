package com.everlaw.edu.domain.approval;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface ApprovalRequestRepository extends JpaRepository<ApprovalRequest, Long> {
    List<ApprovalRequest> findByStatus(ApprovalStatus status);

    @org.springframework.data.jpa.repository.Query("SELECT a.lawReference FROM ApprovalRequest a WHERE a.status != com.everlaw.edu.domain.approval.ApprovalStatus.REJECTED")
    java.util.Set<String> findAllLawReferences();

    List<ApprovalRequest> findByLawReferenceAndStatus(String lawReference, ApprovalStatus status);
    
    void deleteByLawReferenceAndStatus(String lawReference, ApprovalStatus status);
}
