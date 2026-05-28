package com.everlaw.edu.domain.progress;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface MemberWeaknessIndexRepository extends JpaRepository<MemberWeaknessIndex, Long> {
    Optional<MemberWeaknessIndex> findByMemberIdAndLawReference(Long memberId, String lawReference);
    
    java.util.List<MemberWeaknessIndex> findByMemberId(Long memberId);
    
    @org.springframework.data.jpa.repository.Modifying
    @org.springframework.data.jpa.repository.Query("DELETE FROM MemberWeaknessIndex m WHERE m.member.id = :memberId")
    void deleteByMemberId(@org.springframework.data.repository.query.Param("memberId") Long memberId);

    @org.springframework.data.jpa.repository.Modifying
    @org.springframework.data.jpa.repository.Query("DELETE FROM MemberWeaknessIndex m WHERE m.lawReference = :lawReference")
    void deleteByLawReference(@org.springframework.data.repository.query.Param("lawReference") String lawReference);
}
